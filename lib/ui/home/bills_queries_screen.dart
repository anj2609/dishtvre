// Bills & Queries: for the chosen TV, the last payment and when the next
// recharge is due, the payment details (with Auto Pay one tap away), the
// two latest invoices to download, and a way to raise a billing dispute
// by asking for a call back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../recharge/autopay_screen.dart' show AutoPayScreen, autoPayOn;
import '../recharge/recharge_screen.dart' show RechargeScreen, payMethods;
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'my_invoices_screen.dart' show Invoice, MyInvoicesScreen, invoicesFor;
import 'support_screen.dart' show ContactSupportScreen;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
String _month(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class BillsQueriesScreen extends StatefulWidget {
  const BillsQueriesScreen({super.key});

  @override
  State<BillsQueriesScreen> createState() => _BillsQueriesScreenState();
}

class _BillsQueriesScreenState extends State<BillsQueriesScreen> {
  /// Invoices downloading right now, and ones already downloaded.
  final _loading = <String>{};
  final _done = <String>{};

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context, title: 'Bills for which TV?', subtitle: 'Each connection has its own bills.', anyTv: true);
    if (vc != null) app.selectVc(vc);
  }

  Future<void> _download(Invoice i) async {
    if (_loading.contains(i.number)) return;
    HapticFeedback.selectionClick();
    setState(() => _loading.add(i.number));
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _loading.remove(i.number);
      _done.add(i.number);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Invoice ${i.number} downloaded')));
  }

  /// A dispute: pick when we should call, or go to support.
  Future<void> _dispute(AppStore app) async {
    final mobile = app.subscriber?.mobilePretty ?? '';
    final slot = await showSheet<String>(
      context,
      title: 'Have a dispute?',
      subtitle: 'Our billing team will call you on +91 $mobile. When suits you?',
      builder: (ctx) => _CallbackSheet(onSupport: () {
        Navigator.of(ctx).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
      }),
    );
    if (slot == null || !mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Call back booked for $slot. We\'ll call +91 $mobile.')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    if (c == null) return Scaffold(body: SafeArea(child: Column(children: const [Header(title: 'Bills & Queries')])));
    final today = _day(DateTime.now());
    // Bills so far, newest first.
    final bills = invoicesFor(c, today).where((i) => !i.date.isAfter(today)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final last = bills.isEmpty ? null : bills.first;
    final off = c.daysLeft(DateTime.now()) <= 0;
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: autoPayOn,
      builder: (context, auto, _) {
        final autoOn = auto.containsKey(c.vc);
        final paidVia = autoOn ? payMethods[auto[c.vc]!].$2 : 'Google Pay UPI';
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              const Header(title: 'Bills & Queries'),
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
                        Text(c.label, style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('  ·  VC ', style: T.caption.copyWith(color: C.muted)),
                        Text(c.vcPretty, style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        if (app.connections.length > 1) ...[const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20)],
                      ]),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl),
                  children: [
                    Reveal(child: _Summary(last: last?.amount, due: c.switchOffDate, off: off)),
                    if (off) ...[
                      const SizedBox(height: S.sm),
                      Material(
                        color: C.danger.withValues(alpha: 0.1),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen())),
                          child: Padding(
                            padding: const EdgeInsets.all(S.md),
                            child: Row(children: [
                              Icon(Icons.power_off_outlined, size: 20, color: C.danger),
                              const SizedBox(width: S.sm),
                              Expanded(child: Text('${c.label} is switched off.', style: T.label.copyWith(fontSize: 13, color: C.danger))),
                              Text('Recharge', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: C.danger)),
                              Icon(Icons.chevron_right_sharp, size: 18, color: C.danger),
                            ]),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: S.xl),
                    _heading('PAYMENT DETAILS'),
                    Reveal(
                      order: 1,
                      child: Column(children: [
                        _row('Monthly recharge', rupees(c.monthlyRecharge)),
                        _row('Account balance', rupees(c.balance)),
                        if (last != null) _row('Last paid on', _date(last.date)),
                        _row('Paid via', paidVia),
                        // Auto Pay: on or off, and the way to it.
                        InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AutoPayScreen())),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(children: [
                              Expanded(child: Text('Auto Pay', style: T.body.copyWith(fontSize: 14.5, color: C.muted))),
                              Text(autoOn ? 'On' : 'Off',
                                  style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: autoOn ? C.success : C.ink)),
                              Text('  ·  ', style: T.label.copyWith(fontSize: 14.5, color: C.muted)),
                              BrandShade(
                                child: Text(autoOn ? 'Manage' : 'Set up', style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: C.brand)),
                              ),
                              BrandShade(child: Icon(Icons.chevron_right_sharp, size: 20, color: C.brand)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    Row(children: [
                      Expanded(child: _heading('INVOICES')),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyInvoicesScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: BrandShade(child: Text('View all', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand))),
                        ),
                      ),
                    ]),
                    Reveal(
                      order: 2,
                      child: Column(children: [
                        for (final (n, i) in bills.take(2).indexed) ...[
                          if (n > 0) Container(height: 1, color: C.line),
                          _InvoiceRow(invoice: i, loading: _loading.contains(i.number), done: _done.contains(i.number), onDownload: () => _download(i)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    _heading('QUERIES'),
                    const SizedBox(height: S.xs),
                    Reveal(
                      order: 3,
                      child: Material(
                        color: C.surface,
                        child: InkWell(
                          onTap: () => _dispute(app),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(S.lg, S.lg, S.md, S.lg),
                            child: Row(children: [
                              Container(
                                width: 46,
                                height: 46,
                                color: C.brand.withValues(alpha: 0.12),
                                child: BrandShade(child: Icon(Icons.phone_callback_outlined, size: 23, color: C.brand)),
                              ),
                              const SizedBox(width: S.md),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Have a dispute?', style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('Ask for a call back and our billing team will sort it out.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                                ]),
                              ),
                              Icon(Icons.chevron_right_sharp, size: 22, color: C.inkSoft),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: S.xs),
        child: Text(text, style: T.overline),
      );

  Widget _row(String a, String b) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Text(a, style: T.body.copyWith(fontSize: 14.5, color: C.muted)),
          const SizedBox(width: S.lg),
          Expanded(child: Text(b, textAlign: TextAlign.end, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Last payment | next recharge due, on the card gradient.
class _Summary extends StatelessWidget {
  const _Summary({required this.last, required this.due, required this.off});
  final double? last;
  final DateTime due;
  final bool off;

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xD9FFFFFF);
    Widget figure(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: T.overline.copyWith(fontSize: 10.5, color: soft)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: T.price.copyWith(fontSize: 24, color: Colors.white))),
        ]);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(gradient: G.brand),
      child: Stack(children: [
        const Positioned.fill(child: GlossSweep()),
        Padding(
          padding: const EdgeInsets.all(S.lg + 2),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: figure('LAST PAYMENT', last == null ? '—' : rupees(last!.roundToDouble()))),
              Container(width: 1, margin: const EdgeInsets.only(right: S.lg), color: const Color(0x40FFFFFF)),
              Expanded(child: figure(off ? 'SWITCHED OFF ON' : 'NEXT RECHARGE DUE', _date(due))),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// One invoice: month, number, amount, Paid, and a round download button
/// that spins while it downloads and ticks when done.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.loading, required this.done, required this.onDownload});
  final Invoice invoice;
  final bool loading;
  final bool done;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(width: 46, height: 46, color: C.surface, child: Icon(Icons.receipt_outlined, size: 22, color: C.ink)),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_month(i.date), style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(style: T.caption.copyWith(fontSize: 12.5, color: C.muted), children: [
                TextSpan(text: '${i.number}  ·  ${rupees(i.amount)}  ·  '),
                TextSpan(text: 'Paid', style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.success)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: S.sm),
        Semantics(
          button: true,
          label: done ? 'Invoice for ${_month(i.date)} downloaded' : 'Download invoice for ${_month(i.date)}',
          child: InkResponse(
            onTap: loading ? null : onDownload,
            radius: 26,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: done ? C.success : C.brand, width: 1.4)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? Padding(key: const ValueKey('wait'), padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: C.brand))
                    : done
                        ? Icon(Icons.check_sharp, key: const ValueKey('done'), size: 20, color: C.success)
                        : BrandShade(key: const ValueKey('get'), child: Icon(Icons.download_sharp, size: 20, color: C.brand)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// When to call back, or straight to support.
class _CallbackSheet extends StatefulWidget {
  const _CallbackSheet({required this.onSupport});
  final VoidCallback onSupport;

  @override
  State<_CallbackSheet> createState() => _CallbackSheetState();
}

class _CallbackSheetState extends State<_CallbackSheet> {
  static const _slots = [
    ('as soon as possible', 'As soon as possible', 'Usually within 30 minutes'),
    ('this evening', 'This evening', '6 pm – 9 pm'),
    ('tomorrow morning', 'Tomorrow morning', '9 am – 12 pm'),
  ];
  int _pick = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, s) in _slots.indexed) ...[
          if (i > 0) const SizedBox(height: S.sm),
          Material(
            color: C.surface,
            child: InkWell(
              onTap: () => setState(() => _pick = i),
              child: Container(
                padding: const EdgeInsets.all(S.md + 2),
                decoration: BoxDecoration(border: Border.all(color: _pick == i ? C.brand : C.surface, width: 1.4)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.$2, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(s.$3, style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                    ]),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _pick == i ? G.brand : null,
                      border: _pick == i ? null : Border.all(color: C.lineStrong, width: 1.5),
                    ),
                    child: _pick == i ? const Icon(Icons.check_sharp, size: 14, color: Colors.white) : null,
                  ),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: S.xl),
        PrimaryButton(label: 'Request call back', icon: Icons.phone_callback_outlined, onTap: () => Navigator.of(context).pop(_slots[_pick].$1)),
        const SizedBox(height: S.xs),
        TextButton(onPressed: widget.onSupport, child: Text('Chat or call support instead', style: T.label.copyWith(fontSize: 13, color: C.muted))),
      ]),
    );
  }
}
