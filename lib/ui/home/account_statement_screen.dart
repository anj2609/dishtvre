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
                      Text(c.label, style: T.label.copyWith(fontSize: 13, color: C.ink, fontWeight: FontWeight.w600)),
                      Text('  ·  VC ${c.vcPretty}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                      if (app.connections.length > 1) Icon(Icons.keyboard_arrow_down_sharp, color: C.muted, size: 20),
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
                      color: C.surface,
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 19, color: C.ink),
                        const SizedBox(width: S.md),
                        Expanded(child: Text(_month(_selectedMonth), style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
                        Icon(Icons.keyboard_arrow_down_sharp, color: C.muted),
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
                    color: C.surface,
                    child: BrandShade(child: Icon(Icons.file_download_outlined, color: C.brand)),
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
              separatorBuilder: (_, __) => Divider(height: 1, color: C.line),
              itemBuilder: (_, i) => _EntryRow(rows[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One quiet panel with the month in three figures: added, deducted and
/// balance left, split by thin dividers. Balance left is the bold one.
class _Summary extends StatelessWidget {
  const _Summary(this.rows);
  final List<_Entry> rows;

  @override
  Widget build(BuildContext context) {
    final credits = rows.where((e) => e.amount > 0).fold<int>(0, (a, e) => a + e.amount);
    final charges = rows.where((e) => e.amount < 0).fold<int>(0, (a, e) => a - e.amount);
    Widget fig(String label, String value, {bool strong = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: T.price.copyWith(fontSize: strong ? 19 : 16, fontWeight: strong ? FontWeight.w700 : FontWeight.w600, color: strong ? C.ink : C.inkSoft)),
              ),
            ]),
          ),
        );
    final rule = Padding(padding: EdgeInsets.symmetric(vertical: S.md), child: VerticalDivider(width: 1, thickness: 1, color: C.line));
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.md),
      child: Container(
        color: C.surface,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            fig('Added', rupees(credits)),
            rule,
            fig('Deducted', rupees(charges)),
            rule,
            fig('Balance left', rupees(credits - charges), strong: true),
          ]),
        ),
      ),
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
    // White line icons; colour is kept for the amount (green in, red out).
    final tint = C.inkSoft;
    final icon = switch (e.kind) {
      _Kind.opening || _Kind.payment => Icons.account_balance_wallet_outlined,
      _Kind.subscription => Icons.layers_outlined,
      _Kind.additional => Icons.signal_cellular_alt_sharp,
    };
    final sub = e.note == null ? _day(e.date) : '${e.note} · ${_day(e.date)}';
    final amount = '${credit ? '+' : '−'}${rupees(e.amount.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        SizedBox(width: 36, child: Icon(icon, size: 22, color: tint)),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: T.item.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
          ]),
        ),
        Text(amount, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: accent)),
      ]),
    );
  }
}

/// A selectable row in a picker sheet; the chosen one gets an orange check.
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
              color: C.surface,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(note, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  ]),
                ),
                if (selected) BrandShade(child: Icon(Icons.check_sharp, color: C.brand)),
              ]),
            ),
          ),
        ),
      );
}
