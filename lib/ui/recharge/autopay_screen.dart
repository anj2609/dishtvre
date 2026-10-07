// Auto Pay: renew a TV's pack automatically before it switches off. Shows
// the pack and switch-off date, what will be charged and when, how it works
// on a small timeline, and how to pay. "Set up Auto Pay" asks to simulate
// success or failure, plays a "Setting up Auto Pay" check, then shows a
// confirmation or explains what went wrong. Once on, the same screen shows
// it's on and lets you turn it off.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'recharge_screen.dart' show payMethods, PaymentCheckScreen, RechargeScreen, SimButton;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// TVs with Auto Pay on (VC → index into [payMethods]), kept while the app
/// is open.
final autoPayOn = ValueNotifier<Map<String, int>>({});

/// Whether the TV has already switched off.
bool _isOff(Connection c) => !_day(c.switchOffDate).isAfter(_day(DateTime.now()));

/// The switch-off date Auto Pay works against: the real one, or, for a TV
/// that's already off, a month after it's recharged today.
DateTime _nextOff(Connection c) {
  final today = _day(DateTime.now());
  if (!_isOff(c)) return _day(c.switchOffDate);
  // A month on; 31 Jan → 28/29 Feb rather than spilling into March.
  final lastDay = DateTime(today.year, today.month + 2, 0).day;
  return DateTime(today.year, today.month + 1, today.day > lastDay ? lastDay : today.day);
}

/// The next auto-recharge: two days before that switch-off date, or
/// tomorrow if that's sooner.
DateTime _firstCharge(Connection c) {
  final today = _day(DateTime.now());
  final d = _nextOff(c).subtract(const Duration(days: 2));
  return d.isAfter(today) ? d : today.add(const Duration(days: 1));
}

class AutoPayScreen extends StatefulWidget {
  const AutoPayScreen({super.key});

  @override
  State<AutoPayScreen> createState() => _AutoPayScreenState();
}

class _AutoPayScreenState extends State<AutoPayScreen> {
  int _pay = 0;
  bool _failed = false;

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context, title: 'Set up Auto Pay for which TV?', subtitle: 'Auto Pay is set up one connection at a time.', anyTv: true);
    if (vc != null) {
      app.selectVc(vc);
      setState(() => _failed = false);
    }
  }

  Future<void> _pickPay() async {
    final i = await showSheet<int>(
      context,
      title: 'Pay using',
      subtitle: 'Auto Pay works with UPI AutoPay and cards.',
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
    if (i != null) setState(() => _pay = i);
  }

  Future<void> _setUp(Connection c) async {
    final method = payMethods[_pay].$2;
    final first = _firstCharge(c);
    final ok = await showSheet<bool>(
      context,
      title: 'Approve Auto Pay',
      subtitle: 'A request for up to ${rupees(c.monthlyRecharge)} a month goes to $method. Pick what should happen to it.',
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
    final pay = _pay;
    // Done on the confirmation goes back to whatever opened Auto Pay.
    final self = ModalRoute.of(context);
    final done = await Navigator.of(context).push<bool>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: c.monthlyRecharge,
        method: method,
        success: ok,
        title: 'Setting up Auto Pay',
        icon: Icons.autorenew_sharp,
        steps: ['Sending request to $method', 'Waiting for your approval', ok ? 'Turning on Auto Pay' : 'Confirming the mandate'],
        onSuccess: () {
          autoPayOn.value = {...autoPayOn.value, c.vc: pay};
          return _AutoPaySuccess(tv: c.label, vc: c.vcPretty, amount: c.monthlyRecharge, first: first, method: method, from: self);
        },
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    if (!mounted || done != false) return;
    setState(() => _failed = true);
    final next = await showSheet<String>(
      context,
      title: 'Couldn\'t set up Auto Pay',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_sharp, color: C.danger, size: 24),
            const SizedBox(width: S.md),
            Expanded(
              child: Text(
                'The request to $method was declined or timed out, so Auto Pay is still off. No money was taken. Try again, or pick another way to pay.',
                style: T.body.copyWith(color: C.ink, fontSize: 14.5),
              ),
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
    if (next == 'retry') return _setUp(c);
    if (next == 'method') return _pickPay();
  }

  Future<void> _turnOff(Connection c) async {
    final yes = await showSheet<bool>(
      context,
      title: 'Turn off Auto Pay?',
      subtitle: '${c.label} won\'t be recharged automatically. You\'ll need to recharge before ${_short(c.switchOffDate)} to keep watching.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SimButton(label: 'Turn off Auto Pay', icon: Icons.pause_circle_outline_sharp, color: C.danger, onTap: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: S.md),
          PrimaryButton(label: 'Keep it on', onTap: () => Navigator.of(ctx).pop(false)),
        ]),
      ),
    );
    if (yes != true || !mounted) return;
    HapticFeedback.mediumImpact();
    autoPayOn.value = {...autoPayOn.value}..remove(c.vc);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Auto Pay is off for ${c.label}')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    if (c == null) return const Scaffold(body: SafeArea(child: Column(children: [Header(title: 'Auto Pay')])));
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: autoPayOn,
      builder: (context, on, _) {
        final isOn = on.containsKey(c.vc);
        final pay = isOn ? on[c.vc]! : _pay;
        final first = _firstCharge(c);
        final reminder = first.subtract(const Duration(days: 1));
        final off = _isOff(c);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              const Header(title: 'Auto Pay'),
              // Which TV.
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
                  child: InkWell(
                    onTap: app.connections.length > 1 ? () => _pickTv(app) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(c.label, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
                        Text('  ·  VC ', style: T.caption.copyWith(color: C.muted)),
                        Text(c.vcPretty, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
                        if (app.connections.length > 1) ...[const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20)],
                      ]),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xl),
                  children: [
                    if (_failed && !isOn) ...[
                      Container(
                        padding: const EdgeInsets.all(S.md),
                        color: const Color(0x1FF07C88),
                        child: Row(children: [
                          Icon(Icons.error_outline_sharp, color: C.danger, size: 20),
                          const SizedBox(width: S.sm),
                          Expanded(child: Text('Your last request didn\'t go through. Auto Pay is still off.', style: T.label.copyWith(fontSize: 13, color: C.danger))),
                        ]),
                      ),
                      const SizedBox(height: S.lg),
                    ],
                    // Status line: on or off.
                    Reveal(
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: isOn ? C.success : C.faint, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: S.sm),
                        Text(isOn ? 'Auto Pay is on' : 'Auto Pay is off', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: isOn ? C.success : C.muted)),
                      ]),
                    ),
                    const SizedBox(height: S.sm),
                    Text(
                      isOn
                          ? 'We\'ll renew ${c.label}\'s pack automatically before it switches off.'
                          : 'Never miss a recharge. We\'ll renew your pack automatically before it switches off.',
                      style: T.body.copyWith(fontSize: 15, color: C.inkSoft, height: 1.45),
                    ),
                    if (off && !isOn) ...[
                      const SizedBox(height: S.lg),
                      // A switched-off TV needs a recharge before Auto Pay can take over.
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.fromLTRB(S.md, S.md, S.sm, S.md),
                        child: Row(children: [
                          Icon(Icons.power_off_outlined, size: 22, color: C.warning),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Text('${c.label} is switched off. Recharge first, and Auto Pay will renew it from the next cycle.',
                                style: T.caption.copyWith(fontSize: 12.5, color: C.inkSoft)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen())),
                            child: BrandShade(child: Text('Recharge', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: C.brand))),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: S.xl),
                    // Pack and switch-off date on the card gradient.
                    Reveal(
                      order: 1,
                      child: Container(
                        decoration: const BoxDecoration(gradient: G.brand),
                        padding: const EdgeInsets.all(S.lg + 2),
                        child: IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Current pack', style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
                                const SizedBox(height: 4),
                                Text(c.planName, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                              ]),
                            ),
                            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.lg), color: const Color(0x40FFFFFF)),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(off ? 'Switched off on' : 'Switch-off date', style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
                              const SizedBox(height: 4),
                              Text(_short(c.switchOffDate), style: T.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.xxl),
                    // What, when and how.
                    Text('Auto Pay details', style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: S.md),
                    Container(
                      color: C.surface,
                      padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.xs),
                      child: Column(children: [
                        _detail('Amount', '${rupees(c.monthlyRecharge)}/month'),
                        _detail(isOn ? 'Next auto-recharge' : 'First auto-recharge', _date(first)),
                        _detail('Repeats', 'Every month'),
                        _payRow(pay, editable: !isOn),
                      ]),
                    ),
                    const SizedBox(height: S.xxl),
                    Text('How it works', style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: S.lg),
                    _Timeline(reminder: reminder, charge: first, off: _nextOff(c), offLabel: off ? 'Next switch-off' : 'Switch-off date'),
                    const SizedBox(height: S.xl),
                    _how(Icons.event_available_outlined, 'We recharge ', '2 days before', ' your switch-off date'),
                    _how(Icons.notifications_none_sharp, 'You get a reminder ', '24 hours', ' before each payment'),
                    _how(Icons.pause_circle_outline_sharp, 'Pause or turn it off ', 'any time', ' from here'),
                  ],
                ),
              ),
              BottomBar(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!isOn) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.lock_outline_sharp, size: 14, color: C.muted),
                      const SizedBox(width: 6),
                      Text('No money is taken now', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                    ]),
                    const SizedBox(height: S.sm),
                    PrimaryButton(label: 'Set up Auto Pay', onTap: () => _setUp(c)),
                  ] else
                    SimButton(label: 'Turn off Auto Pay', icon: Icons.pause_circle_outline_sharp, color: C.danger, onTap: () => _turnOff(c)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(label, style: T.body.copyWith(fontSize: 14, color: C.muted))),
          Text(value, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _payRow(int pay, {required bool editable}) => InkWell(
        onTap: editable ? _pickPay : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(child: Text('Pay using', style: T.body.copyWith(fontSize: 14, color: C.muted))),
            Icon(payMethods[pay].$1, size: 18, color: C.inkSoft),
            const SizedBox(width: 6),
            Text(payMethods[pay].$2, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700)),
            if (editable) ...[const SizedBox(width: 2), BrandShade(child: Icon(Icons.chevron_right_sharp, size: 20, color: C.brand))],
          ]),
        ),
      );

  Widget _how(IconData icon, String a, String b, String c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: C.ink),
          const SizedBox(width: S.md),
          Expanded(
            child: Text.rich(TextSpan(style: T.body.copyWith(fontSize: 14, color: C.inkSoft), children: [
              TextSpan(text: a),
              TextSpan(text: b, style: T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: c),
            ])),
          ),
        ]),
      );
}

/// Reminder → Auto-recharge → Switch-off, as three stops on one line. The
/// auto-recharge stop is the orange one: it's what keeps the TV on.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.reminder, required this.charge, required this.off, required this.offLabel});
  final DateTime reminder;
  final DateTime charge;
  final DateTime off;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    final stops = [
      (Icons.notifications_none_sharp, 'Reminder', _short(reminder), false),
      (Icons.autorenew_sharp, 'Auto-recharge', _short(charge), true),
      (Icons.power_settings_new_sharp, offLabel, _short(off), false),
    ];
    return Semantics(
      label: 'Reminder on ${_short(reminder)}, auto-recharge on ${_short(charge)}, ${offLabel.toLowerCase()} ${_short(off)}',
      child: ExcludeSemantics(
        child: Stack(children: [
          // The line joining the stops, behind them.
          Positioned(
            left: 0,
            right: 0,
            top: 19,
            child: LayoutBuilder(builder: (context, box) {
              final third = box.maxWidth / 3;
              return Row(children: [
                SizedBox(width: third / 2),
                Expanded(child: Container(height: 2, decoration: const BoxDecoration(gradient: G.brand))),
                Expanded(child: Container(height: 2, color: C.lineStrong)),
                SizedBox(width: third / 2),
              ]);
            }),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, s) in stops.indexed)
              Expanded(
                child: Reveal(
                  order: i,
                  child: Column(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(gradient: s.$4 ? G.brand : null, color: s.$4 ? null : C.surface, shape: BoxShape.circle),
                      child: Icon(s.$1, size: 20, color: s.$4 ? Colors.white : C.inkSoft),
                    ),
                    const SizedBox(height: S.sm),
                    Text(s.$2, textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 12.5, fontWeight: s.$4 ? FontWeight.w700 : FontWeight.w500, color: s.$4 ? C.ink : C.inkSoft)),
                    const SizedBox(height: 2),
                    Text(s.$3, textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success

class _AutoPaySuccess extends StatefulWidget {
  const _AutoPaySuccess({required this.tv, required this.vc, required this.amount, required this.first, required this.method, this.from});
  final String tv;
  final String vc;
  final double amount;
  final DateTime first;
  final String method;

  /// The Auto Pay screen's route: Done closes it too, landing back on the
  /// screen that opened Auto Pay (Home if it's gone).
  final Route<dynamic>? from;

  @override
  State<_AutoPaySuccess> createState() => _AutoPaySuccessState();
}

class _AutoPaySuccessState extends State<_AutoPaySuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final String _mandate = 'MDT${DateTime.now().millisecondsSinceEpoch % 100000000}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() {
    final nav = Navigator.of(context);
    final from = widget.from;
    if (from == null || !from.isActive) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    nav.popUntil((r) => r == from);
    if (!from.isFirst) nav.pop();
  }

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
                        Text('Auto Pay is on', textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text('${widget.tv} will be recharged automatically, so it never switches off.', textAlign: TextAlign.center, style: T.body),
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
                            Expanded(child: _figure('First auto-recharge', _short(widget.first))),
                            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.lg), color: const Color(0x40FFFFFF)),
                            Expanded(child: _figure('Every month', rupees(widget.amount))),
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
                          row('TV', '${widget.tv} · VC ${widget.vc}'),
                          row('Pay using', widget.method),
                          row('Reminder', '24 hours before each payment'),
                          row('Mandate ID', _mandate),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.6,
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, size: 16, color: C.muted),
                        const SizedBox(width: S.sm),
                        Expanded(child: Text('No money was taken today. You can pause or turn off Auto Pay any time from the Auto Pay screen.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted))),
                      ]),
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
