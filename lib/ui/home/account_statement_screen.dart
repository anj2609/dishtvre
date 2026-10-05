// Account Statement: a month of credits and charges for one TV, with a TV
// picker, a month picker and a download button.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../widgets/widgets.dart';

enum _Kind { opening, payment, subscription, additional }

class _Entry {
  const _Entry(this.kind, this.title, this.note, this.date, this.amount);
  final _Kind kind;
  final String title;
  final String? note;
  final DateTime date;
  final int amount;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String _month(DateTime m) => '${_months[m.month - 1]} ${m.year}';

/// Sample statement for a connection and month; the same inputs always give
/// the same rows.
List<_Entry> _statement(Connection c, DateTime month, DateTime now) {
  final current = month.year == now.year && month.month == now.month;
  final last = current ? now.day : DateTime(month.year, month.month + 1, 0).day;
  final rng = math.Random(c.vc.hashCode ^ (month.year * 12 + month.month));
  final entries = <_Entry>[
    _Entry(_Kind.opening, 'Opening Balance', null, DateTime(month.year, month.month, 1), 150 + rng.nextInt(300)),
    _Entry(_Kind.payment, 'Payment Received', null, DateTime(month.year, month.month, math.min(last, 8 + rng.nextInt(6))), 200),
  ];
  for (var d = 1; d <= last; d += 2 + rng.nextInt(3)) {
    entries.add(_Entry(_Kind.subscription, 'Subscription Charges', null, DateTime(month.year, month.month, d), -(1 + rng.nextInt(22))));
  }
  for (final d in [4, 11, 15, 22, 28]) {
    if (d <= last) entries.add(_Entry(_Kind.additional, 'Additional Charges', 'Network Capacity Fee', DateTime(month.year, month.month, d), -(2 + rng.nextInt(19))));
  }
  return entries;
}

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  final _now = DateTime.now();
  late DateTime _selectedMonth = DateTime(_now.year, _now.month);

  List<DateTime> get _choices => [for (var i = 0; i < 3; i++) DateTime(_now.year, _now.month - i)];

  // The shared "Which TV" sheet, same as Change Pack and Add/Remove.
  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context);
    if (vc != null) app.selectVc(vc);
  }

  Future<void> _pickMonth() async {
    final picked = await showSheet<DateTime>(
      context,
      title: 'Select month',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final (i, m) in _choices.indexed) ...[
            _Choice(
              title: _month(m),
              note: i == 0 ? 'Current month · 1 – ${_now.day} ${_months[m.month - 1]}' : '1 – ${DateTime(m.year, m.month + 1, 0).day} ${_months[m.month - 1]}',
              selected: m == _selectedMonth,
              onTap: () => Navigator.of(ctx).pop(m),
            ),
            const SizedBox(height: S.sm + 2),
          ],
        ],
      ),
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  void _download() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Statement downloaded')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    final rows = c == null ? <_Entry>[] : _statement(c, _selectedMonth, _now);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Account Statement'),
          if (c != null)
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
                child: InkWell(
                  onTap: app.connections.length > 1 ? () => _pickTv(app) : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.sm),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(c.label, style: T.label.copyWith(color: C.ink, fontWeight: FontWeight.w800)),
                      Text('  ·  VC ', style: T.caption),
                      Text(c.vcPretty, style: T.label.copyWith(color: C.ink, fontWeight: FontWeight.w800)),
                      if (app.connections.length > 1) const Icon(Icons.keyboard_arrow_down_sharp, color: C.ink, size: 20),
                    ]),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.md),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Month, ${_month(_selectedMonth)}',
                  child: InkWell(
                    onTap: _pickMonth,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: S.md),
                      decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.cardEdge)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: C.ink),
                        const SizedBox(width: S.md),
                        Expanded(child: Text(_month(_selectedMonth), style: T.item.copyWith(fontSize: 16))),
                        const Icon(Icons.keyboard_arrow_down_sharp, color: C.ink),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: S.md),
              Semantics(
                button: true,
                label: 'Download statement',
                child: InkWell(
                  onTap: _download,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(border: Border.all(color: C.brand, width: 1.5)),
                    child: const Icon(Icons.file_download_outlined, color: C.brand),
                  ),
                ),
              ),
            ]),
          ),
          if (rows.isNotEmpty) _Summary(rows),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl + MediaQuery.paddingOf(context).bottom),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: C.line),
              itemBuilder: (_, i) => _EntryRow(rows[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Three solid tiles: amount added, amount deducted and balance left, in the same
/// colours as the Home cards.
class _Summary extends StatelessWidget {
  const _Summary(this.rows);
  final List<_Entry> rows;

  @override
  Widget build(BuildContext context) {
    final credits = rows.where((e) => e.amount > 0).fold<int>(0, (a, e) => a + e.amount);
    final charges = rows.where((e) => e.amount < 0).fold<int>(0, (a, e) => a - e.amount);
    Widget tile(String label, String value, Color fill) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
            color: fill,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.price.copyWith(fontSize: 19, color: Colors.white))),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm),
      child: Row(children: [
        tile('Added', rupees(credits), const Color(0xFF1F7A55)),
        const SizedBox(width: S.sm),
        tile('Deducted', rupees(charges), const Color(0xFFD9552B)),
        const SizedBox(width: S.sm),
        tile('Balance left', rupees(credits - charges), const Color(0xFF2F5FC4)),
      ]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.e);
  final _Entry e;

  @override
  Widget build(BuildContext context) {
    final credit = e.amount > 0;
    final accent = credit ? C.success : C.danger;
    final (icon, tint) = switch (e.kind) {
      _Kind.opening => (Icons.account_balance_wallet_outlined, C.cobalt),
      _Kind.payment => (Icons.account_balance_wallet_outlined, C.success),
      _Kind.subscription => (Icons.layers_outlined, C.violet),
      _Kind.additional => (Icons.signal_cellular_alt_sharp, C.teal),
    };
    final sub = e.note == null ? _day(e.date) : '${e.note} · ${_day(e.date)}';
    final amount = '${credit ? '+' : '−'}${rupees(e.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.md),
      child: Row(children: [
        SizedBox(width: 48, height: 48, child: Icon(icon, size: 26, color: tint)),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: T.item.copyWith(fontSize: 15.5)),
            Text(sub, style: T.caption.copyWith(fontSize: 13)),
          ]),
        ),
        Text(amount, style: T.price.copyWith(fontSize: 17, color: accent)),
      ]),
    );
  }
}

/// A selectable card in a picker sheet; the chosen one gets a brand outline.
class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.note, required this.selected, required this.onTap});

  final String title;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '$title. $note',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(S.lg),
              decoration: BoxDecoration(color: C.surface, border: Border.all(color: selected ? C.brand : C.cardEdge, width: selected ? 1.5 : 1)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: T.item.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(note, style: T.caption.copyWith(fontSize: 13)),
                  ]),
                ),
                if (selected) const Icon(Icons.check_sharp, color: C.brand),
              ]),
            ),
          ),
        ),
      );
}
