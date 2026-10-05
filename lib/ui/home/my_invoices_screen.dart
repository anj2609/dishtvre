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

class _Invoice {
  const _Invoice(this.number, this.date, this.amount);
  final String number;
  final DateTime date;
  final double amount;
}

/// Sample invoices: one a month for the last six months, on a day and for an
/// amount that depend on the TV. The same TV always gives the same list.
List<_Invoice> _invoicesFor(Connection c, DateTime now) {
  final seed = c.vc.hashCode.abs();
  final day = 1 + seed % 27;
  return [
    for (var i = 0; i < 6; i++)
      _Invoice(
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
      builder: (_) => _Calendar(selected: _from, first: DateTime(_today.year - 2), last: _to, rangeStart: _from, rangeEnd: _to),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showSheet<DateTime>(
      context,
      title: 'Select To date',
      builder: (_) => _Calendar(selected: _to, first: _from, last: _today, rangeStart: _from, rangeEnd: _to),
    );
    if (d != null) setState(() => _to = d);
  }

  void _download(_Invoice i) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Invoice ${i.number} downloaded')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    final invoices = c == null
        ? <_Invoice>[]
        : _invoicesFor(c, _today).where((i) => !i.date.isBefore(_from) && !i.date.isAfter(_to)).toList()..sort((a, b) => b.date.compareTo(a.date));
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
            padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.md),
            child: Row(children: [
              Expanded(child: _DateField(label: 'From', date: _from, onTap: _pickFrom)),
              const SizedBox(width: S.md),
              Expanded(child: _DateField(label: 'To', date: _to, onTap: _pickTo)),
            ]),
          ),
          if (invoices.isNotEmpty) _Summary(invoices: invoices, total: total),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.sm),
            child: Row(children: [
              Container(width: 3, height: 12, color: C.brand),
              const SizedBox(width: S.sm),
              Text('${invoices.length} ${invoices.length == 1 ? 'INVOICE' : 'INVOICES'}', style: T.overline.copyWith(fontSize: 11.5)),
              const SizedBox(width: S.sm),
              const Expanded(child: Divider(height: 1, color: C.line)),
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
                    separatorBuilder: (_, __) => const Divider(height: 1, color: C.line),
                    itemBuilder: (_, i) => _InvoiceRow(invoice: invoices[i], tint: const [C.brand, C.violet, C.teal, C.cobalt][i % 4], onDownload: () => _download(invoices[i])),
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
        Text(label, style: T.caption.copyWith(fontSize: 13, color: C.muted)),
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
                decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.cardEdge)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 19, color: C.brand),
                  const SizedBox(width: S.sm),
                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_day(date), style: T.item.copyWith(fontSize: 15)))),
                ]),
              ),
            ),
          ),
        ),
      ]);
}

/// Three solid tiles about the invoices in range.
class _Summary extends StatelessWidget {
  const _Summary({required this.invoices, required this.total});

  final List<_Invoice> invoices;
  final double total;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, Color fill) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(S.md),
            color: fill,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.price.copyWith(fontSize: 19, color: Colors.white))),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.page),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile('Invoices', '${invoices.length}', const Color(0xFF6656E0)),
          const SizedBox(width: S.sm),
          tile('Total billed', rupees(total), const Color(0xFFD9552B)),
          const SizedBox(width: S.sm),
          tile('Latest', '${invoices.first.date.day} ${_months[invoices.first.date.month - 1]}', const Color(0xFF0E9488)),
        ]),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.tint, required this.onDownload});

  final _Invoice invoice;
  final Color tint;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: S.md),
        child: Row(children: [
          SizedBox(width: 48, height: 48, child: Icon(Icons.receipt_long_outlined, size: 28, color: tint)),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice.number, style: T.item.copyWith(fontSize: 16)),
              Row(children: [
                Text(rupees(invoice.amount), style: T.label.copyWith(color: tint, fontWeight: FontWeight.w800)),
                Text('  ·  ${_day(invoice.date)}', style: T.caption.copyWith(fontSize: 13)),
              ]),
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
                decoration: BoxDecoration(border: Border.all(color: C.brand, width: 1.5)),
                child: const Icon(Icons.file_download_outlined, color: C.brand),
              ),
            ),
          ),
        ]),
      );
}

/// A month calendar in a sheet. Days outside [first]..[last] are greyed and
/// can't be picked; the From..To range is tinted and the chosen day is solid.
class _Calendar extends StatefulWidget {
  const _Calendar({required this.selected, required this.first, required this.last, required this.rangeStart, required this.rangeEnd});

  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
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
          Expanded(child: Center(child: Text('${_monthsLong[_shown.month - 1]} ${_shown.year}', style: T.item.copyWith(fontSize: 17)))),
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
            color: chosen ? C.brand : (inRange && enabled ? C.brandSoft : Colors.transparent),
            child: Text('$n', style: T.body.copyWith(fontSize: 16, fontWeight: chosen ? FontWeight.w800 : FontWeight.w600, color: chosen ? Colors.white : (enabled ? C.ink : C.faint))),
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
            decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.cardEdge)),
            child: Icon(icon, color: onTap == null ? C.faint : C.ink),
          ),
        ),
      );
}
