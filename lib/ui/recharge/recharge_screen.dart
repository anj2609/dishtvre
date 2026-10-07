// Recharge: pick a TV, see its pack and switch-off date, choose how long to
// recharge for (or type an amount), see exactly how far the new validity
// reaches on a timeline, apply an offer, choose how to pay, and pay. Pay
// offers "simulate success / failure"; either way a "Checking payment
// status" screen plays first, then success shows the confirmation and
// failure explains what happened and returns here to try again.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../home/account_statement_screen.dart';
import 'autopay_screen.dart';
import 'pay_later_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
/// [m] calendar months on; a day the month doesn't have (31 Jan + 1)
/// becomes its last day (28 or 29 Feb), not a day in the month after.
DateTime _plusMonths(DateTime d, int m) {
  final lastDay = DateTime(d.year, d.month + m + 1, 0).day;
  return DateTime(d.year, d.month + m, d.day > lastDay ? lastDay : d.day);
}

/// The smallest and largest recharge: 7 days and 12 months of the pack.
double _minAmount(double monthly) => (monthly * 7 / 30).ceilToDouble();
double _maxAmount(double monthly) => monthly * 12;

/// How long [amount] lasts from [start]: exact calendar months when it's a
/// whole number of months (so it matches the 1M–12M tiles), otherwise whole
/// days at the pack's daily rate.
@visibleForTesting
DateTime rechargeTill(DateTime start, double amount, double monthly) {
  final months = amount / monthly;
  final m = months.round();
  if (m >= 1 && m <= 12 && (months - m).abs() < 0.001) return _plusMonths(start, m);
  // A small nudge so 747 / 8.3 lands on 90, not 89.999….
  return start.add(Duration(days: (amount * 30 / monthly + 1e-9).floor()));
}

bool _still(BuildContext c) => MediaQuery.of(c).disableAnimations;

/// One offer: a recharge of [months] (or a fixed [price]) with [bonusDays]
/// added on top.
class _Offer {
  const _Offer({required this.title, required this.detail, required this.months, this.price, this.bonusDays = 0});
  final String title;
  final String detail;
  final int months;
  final double? price;
  final int bonusDays;

  double priceFor(double monthly) => price ?? monthly * months;
}

const _offers = [
  _Offer(
      title: '15 days free with a 6-month recharge',
      detail: 'Recharge for 6 months and get 15 extra days of service at no cost.',
      months: 6,
      bonusDays: 15),
  _Offer(
      title: 'Sports & Kids add-on free with a 3-month recharge',
      detail: 'Recharge for 3 months and get the Sports & Kids add-on for those 3 months at no cost.',
      months: 3),
  _Offer(
      title: '10 days free with a 12-month recharge',
      detail: 'Recharge for a year and get 10 extra days of service at no cost.',
      months: 12,
      bonusDays: 10),
];

/// The first step while a payment is checked, in words that fit the method.
String _firstStep(String method) => method.contains('UPI')
    ? 'Waiting for ${method.replaceAll(' UPI', '')}'
    : method.contains('card')
        ? 'Checking your card'
        : 'Waiting for your bank';

/// Ways to pay, shared with Auto Pay.
const payMethods = [
  (Icons.account_balance_wallet_outlined, 'Google Pay UPI'),
  (Icons.qr_code_2_sharp, 'PhonePe UPI'),
  (Icons.payments_outlined, 'Paytm UPI'),
  (Icons.credit_card_sharp, 'Credit / Debit card'),
  (Icons.account_balance_outlined, 'Net banking'),
];

const _durations = [1, 3, 6, 12];

/// "98765 43210"
String _mobilePretty(String m) => m.length == 10 ? '${m.substring(0, 5)} ${m.substring(5)}' : m;

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, this.other, this.mobile});

  /// Someone else's connection (Recharge for Friends & Family): fixed, so
  /// there's no TV switcher and none of your own account's links.
  final Connection? other;

  /// Their mobile number, which gets the SMS.
  final String? mobile;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  int _months = 1;

  /// A typed amount, used instead of [_months] when set.
  double? _custom;

  /// The applied offer, if any (index into [_offers]).
  int? _offer;

  int _pay = _lastPay;
  bool _failed = false;

  /// The way you paid last time, kept between visits and launches.
  static int _lastPay = 0;
  static const _payKey = 'pay_method';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final i = p.getInt(_payKey);
      if (!mounted || i == null || i < 0 || i >= payMethods.length || i == _pay) return;
      setState(() => _pay = _lastPay = i);
    }).catchError((_) {});
  }

  void _setPay(int i) {
    setState(() => _pay = _lastPay = i);
    SharedPreferences.getInstance().then((p) => p.setInt(_payKey, i)).catchError((_) => false);
  }

  void _setMonths(int m) {
    HapticFeedback.selectionClick();
    setState(() {
      _months = m;
      _custom = null;
      _offer = null;
    });
  }

  // ------------------------------------------------------------- the math

  /// Recharge starts from the switch-off date, or today if it has passed.
  DateTime _start(Connection c) {
    final today = _day(DateTime.now());
    final off = _day(c.switchOffDate);
    return off.isAfter(today) ? off : today;
  }

  double _amount(Connection c) {
    if (_offer != null) return _offers[_offer!].priceFor(c.monthlyRecharge);
    return _custom ?? c.monthlyRecharge * _months;
  }

  DateTime _validTill(Connection c) {
    final start = _start(c);
    if (_offer != null) {
      final o = _offers[_offer!];
      return _plusMonths(start, o.months).add(Duration(days: o.bonusDays));
    }
    if (_custom != null) return rechargeTill(start, _custom!, c.monthlyRecharge);
    return _plusMonths(start, _months);
  }

  String _forLabel(Connection c) {
    if (_offer != null) return '${_offers[_offer!].months} months + offer';
    if (_custom != null) {
      final days = _validTill(c).difference(_start(c)).inDays;
      return '$days days';
    }
    return '$_months ${_months == 1 ? 'month' : 'months'}';
  }

  // ------------------------------------------------------------- actions

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context, title: 'Which TV do you want to recharge?', subtitle: 'Recharge one connection at a time.', anyTv: true);
    if (vc != null) {
      app.selectVc(vc);
      setState(() {
        _custom = null;
        _offer = null;
        _failed = false;
      });
    }
  }

  Future<void> _editAmount(Connection c) async {
    final v = await showSheet<double>(
      context,
      title: 'Enter an amount',
      subtitle: 'From ${rupees(_minAmount(c.monthlyRecharge))} (7 days) to ${rupees(_maxAmount(c.monthlyRecharge))} (12 months).',
      builder: (_) => _AmountSheet(monthly: c.monthlyRecharge, initial: _amount(c), start: _start(c)),
    );
    if (v != null) {
      setState(() {
        _custom = v;
        _offer = null;
      });
    }
  }

  void _offerInfo(int i, Connection c) => showSheet<void>(
        context,
        title: 'Offer details',
        builder: (ctx) {
          final o = _offers[i];
          return Padding(
            padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(o.title, style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: S.sm),
              Text(o.detail, style: T.body.copyWith(color: C.inkSoft)),
              const SizedBox(height: S.lg),
              Row(children: [
                Text(rupees(o.priceFor(c.monthlyRecharge)), style: T.price.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(width: S.sm),
                Text('· ${o.months} months${o.bonusDays > 0 ? ' + ${o.bonusDays} days' : ''}', style: T.caption.copyWith(fontSize: 13, color: C.muted)),
              ]),
              const SizedBox(height: S.lg),
              PrimaryButton(
                label: _offer == i ? 'Applied' : 'Apply offer',
                onTap: _offer == i
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _applyOffer(i);
                      },
              ),
            ]),
          );
        },
      );

  void _applyOffer(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _offer = _offer == i ? null : i;
      _custom = null;
      if (_offer != null) _months = _offers[i].months;
    });
  }

  Future<void> _pickPay() async {
    final i = await showSheet<int>(
      context,
      title: 'Pay using',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final (i, m) in payMethods.indexed)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  Icon(m.$1, size: 22, color: C.ink),
                  const SizedBox(width: S.md),
                  Expanded(child: Text(m.$2, style: T.item.copyWith(fontSize: 15, fontWeight: i == _pay ? FontWeight.w700 : FontWeight.w500))),
                  if (i == _pay) BrandShade(child: Icon(Icons.check_sharp, color: C.brand, size: 21)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (i != null) _setPay(i);
  }

  Future<void> _proceed(Connection c) async {
    final app = context.read<AppStore>();
    final amount = _amount(c);
    final valid = _validTill(c);
    final ok = await showSheet<bool>(
      context,
      title: 'Pay ${rupees(amount)}',
      subtitle: 'Using ${payMethods[_pay].$2}. Pick what should happen to this payment.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SimButton(label: 'Simulate success', icon: Icons.check_circle_outline_sharp, color: C.success, onTap: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: S.md),
          SimButton(label: 'Simulate failure', icon: Icons.cancel_outlined, color: C.danger, onTap: () => Navigator.of(ctx).pop(false)),
        ]),
      ),
    );
    if (!mounted || ok == null) return;
    final method = payMethods[_pay].$2;
    // Check the payment first. On success the check screen hands over to the
    // confirmation itself; on failure it comes back here.
    final paid = await Navigator.of(context).push<bool>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: amount,
        method: method,
        success: ok,
        onSuccess: () {
          // Your own TV: show the new validity everywhere and switch it back
          // on if it had stopped. Pay Later can be used again.
          if (widget.other == null) {
            app.recharge(c.vc, amount: amount, validTill: valid);
            payLaterUsed.value = {...payLaterUsed.value}..remove(c.vc);
          }
          return _RechargeSuccess(
              tv: c.label, vc: c.vcPretty, amount: amount, validTill: valid, method: method, forSomeone: widget.other != null, mobile: widget.mobile);
        },
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    if (!mounted || paid != false) return;
    setState(() => _failed = true);
    final next = await showSheet<String>(
      context,
      title: 'Payment failed',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_sharp, color: C.danger, size: 24),
            const SizedBox(width: S.md),
            Expanded(
              child: Text('We couldn\'t complete your payment of ${rupees(amount)}. No money was taken. Please try again, or pick another way to pay.',
                  style: T.body.copyWith(color: C.ink, fontSize: 14.5)),
            ),
          ]),
          const SizedBox(height: S.xl),
          PrimaryButton(label: 'Try again', onTap: () => Navigator.of(ctx).pop('retry')),
          const SizedBox(height: S.sm),
          SecondaryButton(label: 'Pay another way', onTap: () => Navigator.of(ctx).pop('method')),
        ]),
      ),
    );
    if (!mounted) return;
    if (next == 'retry') return _proceed(c);
    if (next == 'method') return _pickPay();
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = widget.other ?? app.connection;
    if (c == null) return const Scaffold(body: SafeArea(child: Column(children: [Header(title: 'Recharge')])));
    final mine = widget.other == null;
    final canSwitch = mine && app.connections.length > 1;
    final amount = _amount(c);
    final valid = _validTill(c);
    final today = _day(DateTime.now());
    final daysLeft = _day(c.switchOffDate).difference(today).inDays;
    final stopped = daysLeft < 0 || c.status == ConnectionStatus.deactivated;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: 'Recharge', subtitle: mine ? null : 'For ${c.label}'),
          // Which TV.
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: canSwitch ? 'Change TV. ${c.label}, VC ${c.vcPretty}' : '${c.label}, VC ${c.vcPretty}',
              child: InkWell(
                onTap: canSwitch ? () => _pickTv(app) : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(c.label, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
                    Text('  ·  VC ', style: T.caption.copyWith(color: C.muted)),
                    Text(c.vcPretty, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
                    if (canSwitch) ...[const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20)],
                  ]),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xl),
              children: [
                if (_failed) ...[
                  Container(
                    padding: const EdgeInsets.all(S.md),
                    color: const Color(0x1FF07C88),
                    child: Row(children: [
                      Icon(Icons.error_outline_sharp, color: C.danger, size: 20),
                      const SizedBox(width: S.sm),
                      Expanded(child: Text('Your last payment didn\'t go through. Try again below.', style: T.label.copyWith(fontSize: 13, color: C.danger))),
                    ]),
                  ),
                  const SizedBox(height: S.lg),
                ],
                // Current pack and switch-off date.
                Reveal(
                  child: Container(
                    color: C.surface,
                    padding: const EdgeInsets.all(S.lg),
                    child: IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Current pack', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                            const SizedBox(height: 4),
                            Text(c.planName, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${rupees(c.monthlyRecharge)}/month', style: T.caption.copyWith(fontSize: 12.5, color: C.inkSoft)),
                          ]),
                        ),
                        Padding(padding: EdgeInsets.symmetric(horizontal: S.lg), child: VerticalDivider(width: 1, thickness: 1, color: C.line)),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(stopped ? 'Switched off on' : 'Switch-off date', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                          const SizedBox(height: 4),
                          Text(_date(c.switchOffDate), style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            stopped ? 'Service is off' : (daysLeft == 0 ? 'Today' : 'In $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'),
                            style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: stopped || daysLeft <= 5 ? C.warning : C.success),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: S.xxl),
                // The amount, big and centred.
                Reveal(
                  order: 1,
                  child: Column(children: [
                    Text.rich(TextSpan(style: T.body.copyWith(fontSize: 14, color: C.muted), children: [
                      const TextSpan(text: 'Recharge for '),
                      TextSpan(text: _forLabel(c), style: T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w700)),
                    ])),
                    const SizedBox(height: S.sm),
                    Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const SizedBox(width: 40),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: amount),
                        duration: Duration(milliseconds: _still(context) ? 0 : 450),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) =>
                            Text(rupees(v.roundToDouble()), style: T.display.copyWith(fontSize: 46, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
                      ),
                      Semantics(
                        button: true,
                        label: 'Enter your own amount',
                        child: IconButton(
                          onPressed: () => _editAmount(c),
                          icon: BrandShade(child: Icon(Icons.edit_outlined, size: 20, color: C.brand)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: S.xs),
                    Text.rich(TextSpan(style: T.body.copyWith(fontSize: 14, color: C.muted), children: [
                      const TextSpan(text: 'Valid till  '),
                      TextSpan(text: _date(valid), style: T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w700)),
                    ])),
                    if (_offer != null) ...[
                      const SizedBox(height: S.md),
                      _AppliedChip(text: 'Offer applied', onRemove: () => _applyOffer(_offer!)),
                    ] else if (_custom != null) ...[
                      const SizedBox(height: S.md),
                      _AppliedChip(text: 'Custom amount', onRemove: () => setState(() => _custom = null)),
                    ],
                  ]),
                ),
                const SizedBox(height: S.xl),
                // How far the recharge reaches.
                Reveal(order: 2, child: _Timeline(today: today, start: _start(c), end: valid, stopped: stopped)),
                const SizedBox(height: S.xl),
                // How long.
                Reveal(
                  order: 3,
                  child: Row(children: [
                    for (final (i, m) in _durations.indexed) ...[
                      if (i > 0) const SizedBox(width: S.sm),
                      Expanded(
                        child: _DurationTile(
                          months: m,
                          price: c.monthlyRecharge * m,
                          // An applied offer lights up its length too (6M for the 6-month offer).
                          selected: _custom == null && (_offer == null ? _months == m : _offers[_offer!].months == m),
                          onTap: () => _setMonths(m),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: S.lg),
                Row(children: [
                  Icon(Icons.info_outline, size: 16, color: C.muted),
                  const SizedBox(width: S.sm),
                  Expanded(child: Text('Keep your set-top box switched on while you recharge.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted))),
                ]),
                const SizedBox(height: S.xxl),
                // Offers.
                Text('Offers for you', style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: S.md),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: _offers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: S.sm + 2),
                    itemBuilder: (_, i) => _OfferCard(
                      offer: _offers[i],
                      price: _offers[i].priceFor(c.monthlyRecharge),
                      applied: _offer == i,
                      onTap: () => _applyOffer(i),
                      onInfo: () => _offerInfo(i, c),
                    ),
                  ),
                ),
                const SizedBox(height: S.xl),
                // For someone else: who hears about it. For you: your history
                // and ways to stay switched on.
                if (!mine)
                  Container(
                    color: C.surface,
                    padding: const EdgeInsets.all(S.lg),
                    child: Row(children: [
                      BrandShade(child: Icon(Icons.sms_outlined, size: 21, color: C.brand)),
                      const SizedBox(width: S.md),
                      Expanded(
                        child: Text(
                          widget.mobile == null
                              ? '${c.label} gets an SMS as soon as it\'s done.'
                              : 'An SMS goes to +91 ${_mobilePretty(widget.mobile!)} as soon as it\'s done.',
                          style: T.body.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ),
                if (mine) ...[
                  // History.
                  Material(
                    color: C.surface,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountStatementScreen())),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(S.lg, 15, S.md, 15),
                        child: Row(children: [
                          Icon(Icons.history_sharp, size: 21, color: C.ink),
                          const SizedBox(width: S.md),
                          Expanded(child: Text('Transaction history', style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600))),
                          BrandShade(child: Icon(Icons.chevron_right_sharp, color: C.brand, size: 22)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: S.sm),
                  Material(
                    color: C.surface,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AutoPayScreen())),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(S.lg, 15, S.md, 15),
                        child: Row(children: [
                          Icon(Icons.autorenew_sharp, size: 21, color: C.ink),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Auto Pay', style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                              Text('Never miss a recharge', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                            ]),
                          ),
                          BrandShade(child: Icon(Icons.chevron_right_sharp, color: C.brand, size: 22)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: S.sm),
                  Material(
                    color: C.surface,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayLaterScreen())),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(S.lg, 15, S.md, 15),
                        child: Row(children: [
                          Icon(Icons.more_time_sharp, size: 21, color: C.ink),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Pay Later', style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                              Text('3 extra days now, pay ₹10 with your next recharge', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                            ]),
                          ),
                          BrandShade(child: Icon(Icons.chevron_right_sharp, color: C.brand, size: 22)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Pay using · Proceed to pay.
          BottomBar(
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Pay using ${payMethods[_pay].$2}. Change',
                  child: InkWell(
                    onTap: _pickPay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('Pay using', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Flexible(
                              child: Text(payMethods[_pay].$2,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600))),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_up_sharp, size: 20, color: C.inkSoft),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: S.md),
              SizedBox(width: 196, child: PrimaryButton(label: 'Pay ${rupees(amount.roundToDouble())}', onTap: () => _proceed(c))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Today → current switch-off → new valid-till, as one bar: the part you
/// already have in grey, the part this recharge adds in the card gradient.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.today, required this.start, required this.end, required this.stopped});
  final DateTime today;
  final DateTime start;
  final DateTime end;
  final bool stopped;

  @override
  Widget build(BuildContext context) {
    final total = end.difference(today).inDays.clamp(1, 100000);
    final have = start.difference(today).inDays.clamp(0, total);
    final added = end.difference(start).inDays;
    final split = have / total;
    return Semantics(
      label: 'Adds $added days. ${stopped ? 'Starts today' : 'Starts ${_short(start)}'}, ends ${_short(end)}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Adds', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
            const SizedBox(width: 6),
            BrandShade(child: Text('+$added days', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: C.brand))),
            const Spacer(),
            Text(stopped ? 'Restarts today' : 'Starts after ${_short(start)}', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
          ]),
          const SizedBox(height: S.sm),
          LayoutBuilder(builder: (context, box) {
            return SizedBox(
              height: 8,
              child: Stack(children: [
                Container(color: C.surface),
                Container(width: box.maxWidth * split, color: C.lineStrong),
                AnimatedPositioned(
                  duration: Duration(milliseconds: _still(context) ? 0 : 450),
                  curve: Curves.easeOutCubic,
                  left: box.maxWidth * split,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(decoration: const BoxDecoration(gradient: G.brand)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Row(children: [
            Text('Today', style: T.caption.copyWith(fontSize: 11.5, color: C.faint)),
            const Spacer(),
            Text(_short(end), style: T.caption.copyWith(fontSize: 11.5, color: C.inkSoft, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _DurationTile extends StatelessWidget {
  const _DurationTile({required this.months, required this.price, required this.selected, required this.onTap});
  final int months;
  final double price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '$months ${months == 1 ? 'month' : 'months'}, ${rupees(price)}',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(gradient: selected ? G.brand : null, color: selected ? null : C.surface),
              child: Column(children: [
                Text('${months}M', style: T.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: selected ? Colors.white : C.ink)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(rupees(price.roundToDouble()), style: T.caption.copyWith(fontSize: 12, color: selected ? const Color(0xE6FFFFFF) : C.muted)),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.price, required this.applied, required this.onTap, required this.onInfo});
  final _Offer offer;
  final double price;
  final bool applied;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: applied,
        label: '${offer.title}, ${rupees(price)}${applied ? ', applied' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200,
            padding: const EdgeInsets.fromLTRB(S.md, S.md, S.xs, S.md),
            decoration: BoxDecoration(
              color: C.surface,
              border: applied ? Border.all(color: C.brand, width: 1.5) : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(offer.title,
                      maxLines: 3, overflow: TextOverflow.ellipsis, style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.35)),
                ),
                SizedBox(
                  width: 32,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Offer details',
                    onPressed: onInfo,
                    icon: Icon(Icons.info_outline, size: 18, color: C.muted),
                  ),
                ),
              ]),
              const Spacer(),
              Row(children: [
                Text(rupees(price.roundToDouble()), style: T.price.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: S.sm),
                  child: applied
                      ? BrandShade(child: Icon(Icons.check_circle_sharp, size: 20, color: C.brand))
                      : BrandShade(child: Text('Apply', style: T.label.copyWith(fontSize: 12.5, color: C.brand))),
                ),
              ]),
            ]),
          ),
        ),
      );
}

class _AppliedChip extends StatelessWidget {
  const _AppliedChip({required this.text, required this.onRemove});
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        color: C.surface,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          BrandShade(child: Icon(Icons.local_offer_outlined, size: 15, color: C.brand)),
          const SizedBox(width: 6),
          Text(text, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close_sharp, size: 16, color: C.muted),
          ),
        ]),
      );
}

/// Type an amount; shows how many days it covers as you type.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.monthly, required this.initial, required this.start});
  final double monthly;
  final double initial;

  /// When the recharge starts (the switch-off date, or today).
  final DateTime start;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final _ctrl = TextEditingController(text: widget.initial.round().toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_ctrl.text) ?? 0;
    final min = _minAmount(widget.monthly), max = _maxAmount(widget.monthly);
    final ok = v >= min && v <= max;
    final till = rechargeTill(widget.start, v, widget.monthly);
    final days = till.difference(widget.start).inDays;
    return Padding(
      padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: C.surface,
          padding: const EdgeInsets.symmetric(horizontal: S.lg),
          child: Row(children: [
            Text('₹', style: T.display.copyWith(fontSize: 28, color: C.muted)),
            const SizedBox(width: S.sm),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (_) => setState(() {}),
                cursorColor: C.brand,
                style: T.display.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: S.sm),
        Text(
            ok
                ? 'Covers $days days, till ${_date(till)}'
                : v < min
                    ? 'Enter at least ${rupees(min)} (7 days)'
                    : 'You can recharge up to ${rupees(max)} (12 months) at a time',
            style: T.caption.copyWith(fontSize: 12.5, color: ok ? C.inkSoft : C.warning)),
        const SizedBox(height: S.lg),
        PrimaryButton(label: 'Use this amount', onTap: ok ? () => Navigator.of(context).pop(v) : null),
      ]),
    );
  }
}

/// A quiet full-width choice in the "simulate success / failure" sheet.
class SimButton extends StatelessWidget {
  const SimButton({super.key, required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: S.sm),
              Text(label, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Success

class _RechargeSuccess extends StatefulWidget {
  const _RechargeSuccess(
      {required this.tv, required this.vc, required this.amount, required this.validTill, required this.method, this.forSomeone = false, this.mobile});
  final String tv;
  final String vc;
  final double amount;
  final DateTime validTill;
  final String method;

  /// Paid for someone else's connection (Friends & Family).
  final bool forSomeone;
  final String? mobile;

  @override
  State<_RechargeSuccess> createState() => _RechargeSuccessState();
}

class _RechargeSuccessState extends State<_RechargeSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final String _txn = 'TXN${DateTime.now().millisecondsSinceEpoch % 10000000000}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.4).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(child: Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted))),
            Text(b, style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: Stack(children: [
          // Behind the content and clear of the status bar.
          const Positioned.fill(child: SafeArea(child: Confetti())),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 48, S.page, S.xl),
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.45, curve: Curves.elasticOut)),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(color: C.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check_sharp, color: Colors.white, size: 46),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.25,
                      Column(children: [
                        Text('Recharge successful', textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text(
                            widget.forSomeone
                                ? '${widget.tv}\'s TV is good to watch till ${_date(widget.validTill)}. We\'ve sent them an SMS.'
                                : '${widget.tv} is good to watch till ${_date(widget.validTill)}.',
                            textAlign: TextAlign.center,
                            style: T.body),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.4,
                      Container(
                        decoration: const BoxDecoration(gradient: G.brand),
                        padding: const EdgeInsets.all(S.lg),
                        child: IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(child: _figure('Amount paid', rupees(widget.amount.roundToDouble()))),
                            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.lg), color: const Color(0x40FFFFFF)),
                            Expanded(child: _figure('Valid till', _short(widget.validTill))),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.5,
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.sm),
                        child: Column(children: [
                          row(widget.forSomeone ? 'For' : 'TV', '${widget.tv} · VC ${widget.vc}'),
                          if (widget.mobile != null) row('SMS sent to', '+91 ${_mobilePretty(widget.mobile!)}'),
                          row('Paid using', widget.method),
                          row('Transaction ID', _txn),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg), child: PrimaryButton(label: 'Done', onTap: _done)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _figure(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.price.copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))),
      ]);
}

// ---------------------------------------------------------------------------
// Checking payment status

/// Plays while the payment is confirmed: a turning arc around the rupee
/// mark, three steps ticking off, and a note not to leave. On success it
/// replaces itself with the confirmation; on failure it closes with false.
class PaymentCheckScreen extends StatefulWidget {
  const PaymentCheckScreen({
    super.key,
    required this.amount,
    required this.method,
    required this.success,
    required this.onSuccess,
    this.title = 'Checking payment status',
    this.icon = Icons.currency_rupee_sharp,
    this.steps,
    this.subtitle,
    this.tag,
  });
  final double amount;
  final String method;
  final bool success;
  final Widget Function() onSuccess;
  final String title;
  final IconData icon;

  /// The three steps to tick off; defaults to the recharge ones.
  final List<String>? steps;

  /// The line under the title; defaults to the amount and how it's paid.
  final String? subtitle;

  /// A small chip under the subtitle, e.g. which TV.
  final String? tag;

  @override
  State<PaymentCheckScreen> createState() => _PaymentCheckState();
}

class _PaymentCheckState extends State<PaymentCheckScreen> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final _timers = <Timer>[];
  int _step = 0;

  List<String> get _steps =>
      widget.steps ?? [_firstStep(widget.method), 'Confirming with your bank', widget.success ? 'Updating your TV' : 'Waiting for confirmation'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timers.isNotEmpty) return;
    final still = MediaQuery.of(context).disableAnimations;
    if (!still) {
      _spin.repeat();
      _pulse.repeat();
    }
    final gap = still ? 300 : 850;
    for (var i = 1; i <= _steps.length; i++) {
      _timers.add(Timer(Duration(milliseconds: gap * i), () {
        if (mounted) setState(() => _step = i);
      }));
    }
    _timers.add(Timer(Duration(milliseconds: gap * _steps.length + 350), _finish));
  }

  void _finish() {
    if (!mounted) return;
    if (widget.success) {
      HapticFeedback.mediumImpact();
      // Built here, once, rather than inside the route's builder: onSuccess
      // may update app state, which mustn't happen in the middle of a build.
      final page = widget.onSuccess();
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    } else {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No going back while the payment is being checked.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.page),
            child: Column(children: [
              const Spacer(flex: 3),
              SizedBox(
                width: 180,
                height: 180,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_spin, _pulse]),
                  builder: (_, __) => CustomPaint(
                    painter: _CheckPainter(spin: _spin.value, pulse: _pulse.value),
                    child: Center(child: BrandShade(child: Icon(widget.icon, size: 52, color: C.brand))),
                  ),
                ),
              ),
              const SizedBox(height: S.xl),
              Text(widget.title, textAlign: TextAlign.center, style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: S.sm),
              Text(widget.subtitle ?? '${rupees(widget.amount.roundToDouble())} via ${widget.method}',
                  textAlign: TextAlign.center, style: T.body.copyWith(color: C.muted)),
              if (widget.tag != null) ...[
                const SizedBox(height: S.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: C.surface,
                  child: Text(widget.tag!, style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: C.inkSoft)),
                ),
              ],
              const SizedBox(height: S.xxl),
              for (final (i, label) in _steps.indexed) _row(i, label),
              const Spacer(flex: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline_sharp, size: 15, color: C.muted),
                const SizedBox(width: 6),
                Flexible(
                    child: Text('Please don\'t close the app or press back.',
                        textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 12.5, color: C.muted))),
              ]),
              const SizedBox(height: S.lg),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _row(int i, String label) {
    final done = i < _step;
    final active = i == _step;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: done || active ? 1 : 0.35,
        child: Row(children: [
          SizedBox(
            width: 24,
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
              child: done
                  ? BrandShade(key: ValueKey('ok'), child: Icon(Icons.check_circle_sharp, size: 22, color: C.brand))
                  : active
                      ? Padding(key: ValueKey('wait'), padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: C.inkSoft))
                      : Icon(Icons.circle_outlined, key: ValueKey('idle'), size: 20, color: C.faint),
            ),
          ),
          const SizedBox(width: S.md),
          Expanded(child: Text(label, style: T.item.copyWith(fontSize: 14.5, fontWeight: done ? FontWeight.w600 : FontWeight.w500))),
        ]),
      ),
    );
  }
}

/// A soft ring that breathes outward and an orange arc that turns.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.spin, required this.pulse});
  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      base * (0.55 + 0.45 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFE5622E).withValues(alpha: 0.45 * (1 - pulse)),
    );
    final r = base * 0.55;
    final track = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = C.surface);
    final start = spin * 2 * math.pi - math.pi / 2;
    canvas.drawArc(
      track,
      start,
      math.pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: const [Color(0x00E5622E), Color(0xFFFF8A5B), Color(0xFFC24A22)],
          stops: const [0, 0.3, 0.375],
          transform: GradientRotation(start),
        ).createShader(track),
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.spin != spin || old.pulse != pulse;
}
