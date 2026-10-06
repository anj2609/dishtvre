// My Invoices: pick a TV and a From / To date range, see the invoices in
// that range and download any of them.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../widgets/widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

class Invoice {
  const Invoice(this.number, this.date, this.amount);
  final String number;
  final DateTime date;
  final double amount;
}

/// Sample invoices: one a month for the last six months, on a day and for an
/// amount that depend on the TV. The same TV always gives the same list.
List<Invoice> invoicesFor(Connection c, DateTime now) {
  final seed = c.vc.hashCode.abs();
  final day = 1 + seed % 27;
  return [
    for (var i = 0; i < 6; i++)
      Invoice(
        'JPM-${34567890 + seed % 9000 + i * 137}',
        DateTime(now.year, now.month - i, day),
        c.monthlyRecharge + (seed >> (i + 1)) % 40,
      ),
  ];
}

class MyInvoicesScreen extends StatefulWidget {
  const MyInvoicesScreen({super.key});

  @override
  State<MyInvoicesScreen> createState() => _MyInvoicesScreenState();
}

class _MyInvoicesScreenState extends State<MyInvoicesScreen> {
  final _today = _dateOnly(DateTime.now());
  late DateTime _from = _today.subtract(const Duration(days: 45));
  late DateTime _to = _today;

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context);
    if (vc != null) app.selectVc(vc);
  }

  Future<void> _pickFrom() async {
    final d = await showSheet<DateTime>(
      context,
      title: 'Select From date',
      builder: (_) => CalendarPicker(selected: _from, first: DateTime(_today.year - 2), last: _to, rangeStart: _from, rangeEnd: _to),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showSheet<DateTime>(
      context,
      title: 'Select To date',
      builder: (_) => CalendarPicker(selected: _to, first: _from, last: _today, rangeStart: _from, rangeEnd: _to),
    );
    if (d != null) setState(() => _to = d);
  }

  void _download(Invoice i) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Invoice ${i.number} downloaded')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    final invoices = c == null
        ? <Invoice>[]
        : invoicesFor(c, _today).where((i) => !i.date.isBefore(_from) && !i.date.isAfter(_to)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final total = invoices.fold<double>(0, (a, i) => a + i.amount);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'My Invoices'),
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
            padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.md),
            child: Row(children: [
              Expanded(child: _DateField(label: 'From', date: _from, onTap: _pickFrom)),
              const SizedBox(width: S.md),
              Expanded(child: _DateField(label: 'To', date: _to, onTap: _pickTo)),
            ]),
          ),
          if (invoices.isNotEmpty) _Summary(invoices: invoices, total: total),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, S.xs),
            child: Row(children: [
              Text('Invoices', style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${invoices.length}', style: T.caption.copyWith(fontSize: 12, color: C.faint)),
            ]),
          ),
          Expanded(
            child: invoices.isEmpty
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(padding: EdgeInsets.all(S.page), child: EmptyNote(icon: Icons.receipt_long_outlined, title: 'No invoices in these dates', body: 'Try a wider From and To range.')),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl + MediaQuery.paddingOf(context).bottom),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: C.line),
                    itemBuilder: (_, i) => _InvoiceRow(invoice: invoices[i], onDownload: () => _download(invoices[i])),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: '$label date, ${_day(date)}',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: S.md),
                color: C.surface,
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: C.ink),
                  const SizedBox(width: S.sm),
                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_day(date), style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)))),
                ]),
              ),
            ),
          ),
        ),
      ]);
}

/// One quiet panel: invoice count, total billed (the bold one) and the
/// latest invoice date, split by thin dividers.
class _Summary extends StatelessWidget {
  const _Summary({required this.invoices, required this.total});

  final List<Invoice> invoices;
  final double total;

  @override
  Widget build(BuildContext context) {
    Widget fig(String label, String value, {bool strong = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
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
      padding: const EdgeInsets.symmetric(horizontal: S.page),
      child: Container(
        color: C.surface,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            fig('Invoices', '${invoices.length}'),
            rule,
            fig('Total billed', rupees(total), strong: true),
            rule,
            fig('Latest', '${invoices.first.date.day} ${_months[invoices.first.date.month - 1]}'),
          ]),
        ),
      ),
    );
  }
}

/// One invoice: white line icon, number, amount and date in grey, and a
/// quiet download button with the orange icon as the only accent.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onDownload});

  final Invoice invoice;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(width: 36, child: Icon(Icons.receipt_long_outlined, size: 22, color: C.inkSoft)),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice.number, style: T.item.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${rupees(invoice.amount)}  ·  ${_day(invoice.date)}', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
            ]),
          ),
          Semantics(
            button: true,
            label: 'Download invoice ${invoice.number}',
            child: InkWell(
              onTap: onDownload,
              child: Container(
                width: 44,
                height: 44,
                color: C.surface,
                child: BrandShade(child: Icon(Icons.file_download_outlined, size: 21, color: C.brand)),
              ),
            ),
          ),
        ]),
      );
}

/// A month calendar in a sheet. Days outside [first]..[last] are greyed and
/// can't be picked; the From..To range is tinted and the chosen day is solid.
/// A month calendar in a sheet: days between [first] and [last] can be
/// picked (the sheet closes with the day), [rangeStart]–[rangeEnd] is shaded.
class CalendarPicker extends StatefulWidget {
  const CalendarPicker({super.key, required this.selected, required this.first, required this.last, required this.rangeStart, required this.rangeEnd});

  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  late DateTime _shown = DateTime(widget.selected.year, widget.selected.month);

  bool get _canPrev => DateTime(_shown.year, _shown.month - 1).isAfter(DateTime(widget.first.year, widget.first.month - 1));
  bool get _canNext => DateTime(_shown.year, _shown.month + 1).isBefore(DateTime(widget.last.year, widget.last.month + 1));

  void _move(int by) => setState(() => _shown = DateTime(_shown.year, _shown.month + by));

  @override
  Widget build(BuildContext context) {
    final days = DateTime(_shown.year, _shown.month + 1, 0).day;
    final lead = DateTime(_shown.year, _shown.month, 1).weekday % 7;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _Arrow(Icons.chevron_left_sharp, 'Previous month', _canPrev ? () => _move(-1) : null),
          Expanded(child: Center(child: Text('${_monthsLong[_shown.month - 1]} ${_shown.year}', style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w600)))),
          _Arrow(Icons.chevron_right_sharp, 'Next month', _canNext ? () => _move(1) : null),
        ]),
        const SizedBox(height: S.md),
        Row(children: [
          for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Expanded(child: Center(child: Text(d, style: T.caption.copyWith(fontWeight: FontWeight.w800, color: C.muted)))),
        ]),
        const SizedBox(height: S.sm),
        for (var r = 0; r < rows; r++)
          Row(children: [
            for (var col = 0; col < 7; col++) Expanded(child: _cell(r * 7 + col - lead + 1, days)),
          ]),
      ]),
    );
  }

  Widget _cell(int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: 42);
    final d = DateTime(_shown.year, _shown.month, n);
    final enabled = !d.isBefore(widget.first) && !d.isAfter(widget.last);
    final chosen = d == widget.selected;
    final inRange = !d.isBefore(widget.rangeStart) && !d.isAfter(widget.rangeEnd);
    return Semantics(
      button: enabled,
      selected: chosen,
      label: _day(d),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? () => Navigator.of(context).pop(d) : null,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(gradient: chosen ? G.brand : null, color: chosen ? null : (inRange && enabled ? C.surface : Colors.transparent)),
            child: Text('$n', style: T.body.copyWith(fontSize: 15, fontWeight: chosen ? FontWeight.w700 : FontWeight.w500, color: chosen ? Colors.white : (enabled ? C.ink : C.faint))),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            color: C.surface,
            child: Icon(icon, color: onTap == null ? C.faint : C.ink),
          ),
        ),
      );
}
