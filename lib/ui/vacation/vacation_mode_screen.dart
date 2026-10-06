// Pause Connection ("Vacation Mode"): pause a TV's pack while you're away
// and have it switch back on by itself. Pick the TV and the dates (7 to 90
// days), review the pause and the credit you get back, activate, and a
// short check plays before the confirmation. A TV with a pause booked can
// change or cancel it; one already on vacation can end it early; one that's
// switched off is sent to Recharge. Every state has a way forward.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../home/my_invoices_screen.dart' show CalendarPicker;
import '../recharge/recharge_screen.dart' show PaymentCheckScreen, RechargeScreen;
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

const _minDays = 7;
const _maxDays = 90;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime get _today => _day(DateTime.now());

/// Pauses booked this session: VC → (pause from, resume on).
final vacations = ValueNotifier<Map<String, (DateTime, DateTime)>>({});

enum _Can { ok, booked, onVacation, off }

_Can _can(Connection c) {
  if (vacations.value.containsKey(c.vc)) return _Can.booked;
  if (c.status == ConnectionStatus.vacation) return _Can.onVacation;
  if (c.status == ConnectionStatus.deactivated || c.daysLeft(DateTime.now()) <= 0) return _Can.off;
  return _Can.ok;
}

/// When a TV that's already on vacation comes back (mock data has no date).
DateTime _backOn(Connection c) => _today.add(const Duration(days: 9));

/// The pause has to start while the TV still has days left, and within
/// two months.
DateTime _lastStart(Connection c) {
  final off = _day(c.switchOffDate);
  final cap = _today.add(const Duration(days: 60));
  final tomorrow = _today.add(const Duration(days: 1));
  final last = off.isBefore(cap) ? off : cap;
  return last.isBefore(tomorrow) ? tomorrow : last;
}

/// Money back for the paused days, as credit when the TV resumes.
double _credit(Connection c, int days) => (c.monthlyRecharge * days / 30).roundToDouble();

class VacationModeScreen extends StatefulWidget {
  const VacationModeScreen({super.key});

  @override
  State<VacationModeScreen> createState() => _VacationModeScreenState();
}

class _VacationModeScreenState extends State<VacationModeScreen> {
  String? _forVc;

  /// Changing the dates of a booked vacation (it stays booked until the
  /// new dates are activated).
  bool _editing = false;
  late DateTime _from;
  late DateTime _resume;

  int get _days => _resume.difference(_from).inDays;
  bool get _valid => _days >= _minDays && _days <= _maxDays;

  /// Fresh dates whenever the TV changes: from tomorrow, for two weeks (or
  /// the dates already booked, to change them).
  void _datesFor(Connection c) {
    if (_forVc == c.vc) return;
    if (_forVc != null) _editing = false;
    _forVc = c.vc;
    final booked = vacations.value[c.vc];
    _from = booked?.$1 ?? _today.add(const Duration(days: 1));
    _resume = booked?.$2 ?? _from.add(const Duration(days: 14));
  }

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context, title: 'Pause which TV?', subtitle: 'Vacation Mode is set one connection at a time.', anyTv: true);
    if (vc != null) app.selectVc(vc);
  }

  Future<void> _pickFrom(Connection c) async {
    final first = _today.add(const Duration(days: 1));
    final d = await showSheet<DateTime>(
      context,
      title: 'Pause from',
      subtitle: 'Your TV keeps working until this day.',
      builder: (_) => CalendarPicker(selected: _from, first: first, last: _lastStart(c), rangeStart: _from, rangeEnd: _resume),
    );
    if (d == null) return;
    setState(() {
      // Keep the same length of pause, within the limits.
      final days = _days.clamp(_minDays, _maxDays);
      _from = d;
      _resume = d.add(Duration(days: days));
    });
  }

  Future<void> _pickResume() async {
    final d = await showSheet<DateTime>(
      context,
      title: 'Resume on',
      subtitle: 'Your TV switches back on by itself that morning.',
      builder: (_) => CalendarPicker(
        selected: _resume,
        first: _from.add(const Duration(days: _minDays)),
        last: _from.add(const Duration(days: _maxDays)),
        rangeStart: _from,
        rangeEnd: _resume,
      ),
    );
    if (d != null) setState(() => _resume = d);
  }

  void _review(Connection c) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReviewScreen(c: c, from: _from, resume: _resume)));
  }

  void _recharge(AppStore app, Connection c) {
    app.selectVc(c.vc);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen()));
  }

  Future<void> _cancelBooked(Connection c) async {
    final b = vacations.value[c.vc]!;
    final yes = await _confirm(
      title: 'Cancel this vacation?',
      subtitle: '${c.label} won\'t pause on ${_short(b.$1)}. It keeps running as usual.',
      action: 'Cancel vacation',
      keep: 'Keep it',
    );
    if (yes != true || !mounted) return;
    HapticFeedback.mediumImpact();
    vacations.value = {...vacations.value}..remove(c.vc);
    _forVc = null;
    _toast('Vacation cancelled for ${c.label}');
  }

  Future<void> _endNow(AppStore app, Connection c) async {
    final yes = await _confirm(
      title: 'End the vacation now?',
      subtitle: '${c.label} switches back on right away instead of on ${_short(_backOn(c))}.',
      action: 'End vacation now',
      keep: 'Stay on vacation',
    );
    if (yes != true || !mounted) return;
    HapticFeedback.mediumImpact();
    app.endVacation(c.vc);
    _toast('${c.label} is back on');
  }

  Future<bool?> _confirm({required String title, required String subtitle, required String action, required String keep}) => showSheet<bool>(
        context,
        title: title,
        subtitle: subtitle,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrimaryButton(label: action, onTap: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: S.sm),
            SecondaryButton(label: keep, onTap: () => Navigator.of(ctx).pop(false)),
          ]),
        ),
      );

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    if (c == null) return Scaffold(body: SafeArea(child: Column(children: const [Header(title: 'Vacation Mode')])));
    return ValueListenableBuilder<Map<String, (DateTime, DateTime)>>(
      valueListenable: vacations,
      builder: (context, _, __) {
        _datesFor(c);
        final can = _can(c) == _Can.booked && _editing ? _Can.ok : _can(c);
        final booked = vacations.value[c.vc];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              const Header(title: 'Vacation Mode'),
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
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xl),
                  children: [
                    Reveal(child: _PackBand(c: c)),
                    const SizedBox(height: S.xxl),
                    Reveal(
                      order: 1,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Going on vacation?', style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            'Pause your pack while you\'re away. It resumes by itself on the date you choose, and the days you don\'t watch come back as credit.',
                            style: T.body.copyWith(fontSize: 14, height: 1.5)),
                        const SizedBox(height: S.md),
                        _status(c, can, booked),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    if (can == _Can.ok) ...[
                      Text('SELECT DATES', style: T.overline),
                      const SizedBox(height: S.md),
                      Reveal(order: 2, child: _dates(c)),
                      const SizedBox(height: S.md),
                      // How long, and quick lengths to pick from.
                      Wrap(spacing: S.sm, runSpacing: S.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          color: (_valid ? C.brand : C.danger).withValues(alpha: 0.12),
                          child: Text(
                            _valid ? 'Paused for $_days days' : 'Pick $_minDays to $_maxDays days',
                            style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _valid ? C.brand : C.danger),
                          ),
                        ),
                      ]),
                      const SizedBox(height: S.lg),
                      Text('Quick pick', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                      const SizedBox(height: S.sm),
                      Wrap(spacing: S.sm, runSpacing: S.sm, children: [
                        for (final (n, label) in const [(7, '1 week'), (14, '2 weeks'), (30, '1 month'), (60, '2 months')])
                          Pick(label: label, selected: _days == n, onTap: () => setState(() => _resume = _from.add(Duration(days: n)))),
                      ]),
                      const SizedBox(height: S.xxl),
                      _how(Icons.tv_off_outlined, 'Channels stop ', 'while you\'re away', ''),
                      _how(Icons.event_repeat_outlined, 'Your TV ', 'switches back on by itself', ' on the resume date'),
                      _how(Icons.savings_outlined, 'Unused days come back as ', 'credit', ' when you return'),
                    ] else
                      Reveal(order: 2, child: _stateCard(app, c, can, booked)),
                  ],
                ),
              ),
              BottomBar(child: _bottom(app, c, can)),
            ]),
          ),
        );
      },
    );
  }

  /// Can it pause? Green when yes; otherwise what's going on.
  Widget _status(Connection c, _Can can, (DateTime, DateTime)? booked) {
    final (icon, text, tone) = switch (can) {
      _Can.ok => (Icons.check_circle_outline_sharp, 'Eligible · pause for $_minDays to $_maxDays days', C.success),
      _Can.booked => (Icons.event_available_outlined, 'Vacation booked · ${_short(booked!.$1)} – ${_short(booked.$2)}', C.info),
      _Can.onVacation => (Icons.luggage_outlined, 'On vacation · back on ${_short(_backOn(c))}', C.info),
      _Can.off => (Icons.error_outline_sharp, 'Switched off · recharge to use Vacation Mode', C.danger),
    };
    return Row(children: [
      Icon(icon, size: 19, color: tone),
      const SizedBox(width: S.sm),
      Expanded(child: Text(text, style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: tone))),
    ]);
  }

  /// Pause from | Resume on, each opening a calendar.
  Widget _dates(Connection c) {
    Widget half(String label, DateTime d, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            label: '$label, ${_date(d)}. Change',
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.lg, S.md + 2, S.md, S.md + 2),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                      const SizedBox(height: 3),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(_date(d), style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20),
                ]),
              ),
            ),
          ),
        );
    return Material(
      color: C.surface,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          half('Pause from', _from, () => _pickFrom(c)),
          Container(width: 1, margin: const EdgeInsets.symmetric(vertical: S.md), color: C.line),
          half('Resume on', _resume, _pickResume),
        ]),
      ),
    );
  }

  /// For a TV that can't pick dates right now: what's booked or going on,
  /// and what to do about it.
  Widget _stateCard(AppStore app, Connection c, _Can can, (DateTime, DateTime)? booked) {
    final (icon, title, body) = switch (can) {
      _Can.booked => (
          Icons.event_available_outlined,
          '${_short(booked!.$1)} – ${_short(booked.$2)}',
          '${c.label} pauses on ${_date(booked.$1)} and switches back on by itself on ${_date(booked.$2)}. '
              '${rupees(_credit(c, booked.$2.difference(booked.$1).inDays))} comes back as credit.',
        ),
      _Can.onVacation => (
          Icons.luggage_outlined,
          'Back on ${_date(_backOn(c))}',
          '${c.label} is paused right now. End the vacation to switch it back on today.',
        ),
      _ => (
          Icons.power_off_outlined,
          '${c.label} is switched off',
          'Recharge first. Once it\'s back on, you can pause it for $_minDays to $_maxDays days.',
        ),
    };
    return Container(
      color: C.surface,
      padding: const EdgeInsets.all(S.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 24, color: can == _Can.off ? C.danger : C.ink),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: T.body.copyWith(fontSize: 13.5)),
            if (can == _Can.booked) ...[
              const SizedBox(height: S.md),
              InkWell(
                onTap: () => _cancelBooked(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Cancel vacation', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.danger)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _bottom(AppStore app, Connection c, _Can can) => switch (can) {
        _Can.ok => PrimaryButton(label: 'Continue', onTap: _valid ? () => _review(c) : null),
        // Back to the dates, starting from the booked ones.
        _Can.booked => PrimaryButton(
            label: 'Change dates',
            onTap: () => setState(() {
              _editing = true;
              _forVc = null;
            }),
          ),
        _Can.onVacation => PrimaryButton(label: 'End vacation now', onTap: () => _endNow(app, c)),
        _Can.off => PrimaryButton(label: 'Recharge ${c.label}', onTap: () => _recharge(app, c)),
      };

  Widget _how(IconData icon, String a, String b, String c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: C.ink),
          const SizedBox(width: S.md),
          Expanded(
            child: Text.rich(TextSpan(style: T.body.copyWith(fontSize: 13.5, color: C.inkSoft), children: [
              TextSpan(text: a),
              TextSpan(text: b, style: T.body.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: c),
            ])),
          ),
        ]),
      );
}

/// The pack on the card gradient: name and what it costs a month.
class _PackBand extends StatelessWidget {
  const _PackBand({required this.c});
  final Connection c;

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xD9FFFFFF);
    return Container(
      decoration: const BoxDecoration(gradient: G.brand),
      padding: const EdgeInsets.all(S.lg),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 46,
            color: const Color(0x29FFFFFF),
            child: const Icon(Icons.tv_sharp, color: Colors.white, size: 24),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('CURRENT PACK', style: T.overline.copyWith(fontSize: 10.5, color: soft)),
              const SizedBox(height: 3),
              Text(c.planName,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.md), color: const Color(0x40FFFFFF)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('MONTHLY', style: T.overline.copyWith(fontSize: 10.5, color: soft)),
            const SizedBox(height: 3),
            Text(rupees(c.monthlyRecharge), style: T.price.copyWith(fontSize: 20, color: Colors.white)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review

class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen({required this.c, required this.from, required this.resume});
  final Connection c;
  final DateTime from;
  final DateTime resume;

  int get _days => resume.difference(from).inDays;

  Future<void> _activate(BuildContext context) async {
    final days = _days;
    final credit = _credit(c, days);
    final newOff = _day(c.switchOffDate).add(Duration(days: days));
    await Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: 0,
        method: '',
        success: true,
        title: 'Activating Vacation Mode',
        icon: Icons.luggage_outlined,
        subtitle: '${c.label}  ·  ${_short(from)} – ${_short(resume)}',
        steps: ['Checking ${c.label} can pause', 'Booking your pause', 'Setting up the automatic restart'],
        onSuccess: () {
          vacations.value = {...vacations.value, c.vc: (from, resume)};
          return _VacationSuccess(tv: c.label, vc: c.vcPretty, from: from, resume: resume, credit: credit, newOff: newOff);
        },
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final newOff = _day(c.switchOffDate).add(Duration(days: days));
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted)),
            const SizedBox(width: S.lg),
            Expanded(child: Text(b, textAlign: TextAlign.end, style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
        );
    Widget money(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted))),
            Text(b, style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Review Vacation Mode'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                Row(children: [
                  Expanded(child: Text('PAUSE PERIOD', style: T.overline)),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: BrandShade(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_outlined, size: 15, color: C.brand),
                          const SizedBox(width: 4),
                          Text('Edit', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand)),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${_date(from)} – ${_date(resume)}', style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Resumes automatically on ${_date(resume)}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: S.lg),
                _Trip(from: from, resume: resume, days: days),
                const SizedBox(height: S.xl),
                Container(
                  color: C.surface,
                  padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.xs),
                  child: Column(children: [
                    row('Connection', '${c.label} · ${c.vcPretty}'),
                    row('Pack', '${c.planName} · paused'),
                    row('Switch-off date', '${_short(c.switchOffDate)} → ${_short(newOff)}'),
                  ]),
                ),
                const SizedBox(height: S.lg),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 16, color: C.muted),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text('Channels stop on ${_short(from)}. Back sooner? End the vacation early from Pause Connection.',
                        style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                  ),
                ]),
              ],
            ),
          ),
          // What comes back, and the button.
          Container(
            decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
            padding: EdgeInsets.fromLTRB(S.page, S.lg, S.page, S.md + MediaQuery.paddingOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('CREDIT ON RESUME', style: T.overline),
              const SizedBox(height: S.sm),
              money('Pause duration', '$days days'),
              money('Monthly recharge', rupees(c.monthlyRecharge)),
              Container(height: 1, margin: const EdgeInsets.symmetric(vertical: S.sm), color: C.line),
              Row(children: [
                Expanded(child: Text('Credit', style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
                Text(rupees(_credit(c, days)), style: T.price.copyWith(fontSize: 24, color: C.success)),
              ]),
              const SizedBox(height: S.lg),
              PrimaryButton(label: 'Activate Vacation Mode', onTap: () => _activate(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Pause → resume on one line: two dates, the days away in between.
class _Trip extends StatelessWidget {
  const _Trip({required this.from, required this.resume, required this.days, this.progress});
  final DateTime from;
  final DateTime resume;
  final int days;

  /// How much of the line is drawn (for the success animation); full when null.
  final Animation<double>? progress;

  @override
  Widget build(BuildContext context) {
    Widget end(String label, DateTime d, CrossAxisAlignment align) => Column(crossAxisAlignment: align, children: [
          Text(label, style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 2),
          Text(_short(d), style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
        ]);
    Widget line(double t) => LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: 26,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
              Container(height: 2, color: C.line),
              Container(height: 2, width: w * t, decoration: const BoxDecoration(gradient: G.brand)),
              // A plane riding the line.
              Positioned(
                left: (w * t - 11).clamp(0.0, w - 22),
                child: BrandShade(child: RotatedBox(quarterTurns: 1, child: Icon(Icons.flight_sharp, size: 22, color: C.brand))),
              ),
            ]),
          );
        });
    return Semantics(
      label: 'Pauses ${_short(from)}, resumes ${_short(resume)}, $days days',
      child: ExcludeSemantics(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          end('Pauses', from, CrossAxisAlignment.start),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(children: [
              Text('$days days away', style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: C.inkSoft)),
              progress == null ? line(1) : AnimatedBuilder(animation: progress!, builder: (_, __) => line(progress!.value)),
            ]),
          ),
          const SizedBox(width: S.md),
          end('Resumes', resume, CrossAxisAlignment.end),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success

class _VacationSuccess extends StatefulWidget {
  const _VacationSuccess({required this.tv, required this.vc, required this.from, required this.resume, required this.credit, required this.newOff});
  final String tv;
  final String vc;
  final DateTime from;
  final DateTime resume;
  final double credit;
  final DateTime newOff;

  @override
  State<_VacationSuccess> createState() => _VacationSuccessState();
}

class _VacationSuccessState extends State<_VacationSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.3).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.resume.difference(widget.from).inDays;
    Widget row(String a, String b, {Color? tone}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted)),
            const SizedBox(width: S.md),
            Expanded(
              child: Text(b,
                  textAlign: TextAlign.end,
                  style: T.label.copyWith(fontSize: tone == null ? 14 : 16, fontWeight: tone == null ? FontWeight.w600 : FontWeight.w800, color: tone)),
            ),
          ]),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 44, S.page, S.xl),
                  children: [
                    // A suitcase on the card gradient, with a sun rising behind.
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 120,
                        child: Stack(alignment: Alignment.center, children: [
                          Positioned(
                            top: 0,
                            right: 14,
                            child: FadeTransition(
                              opacity: CurvedAnimation(parent: _a, curve: const Interval(0.2, 0.6)),
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.6), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: _a, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic))),
                                child: Icon(Icons.wb_sunny_outlined, size: 40, color: C.warning),
                              ),
                            ),
                          ),
                          ScaleTransition(
                            scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.4, curve: Curves.elasticOut)),
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: const BoxDecoration(gradient: G.brand),
                              child: const Icon(Icons.luggage_sharp, color: Colors.white, size: 46),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.25,
                      Column(children: [
                        Text('Vacation Mode is on', textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text('${widget.tv} pauses on ${_short(widget.from)} and switches back on by itself on ${_short(widget.resume)}. Enjoy your trip.',
                            textAlign: TextAlign.center, style: T.body),
                      ]),
                    ),
                    const SizedBox(height: S.xxl),
                    _fade(
                      0.38,
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, S.md),
                        child: _Trip(
                          from: widget.from,
                          resume: widget.resume,
                          days: days,
                          progress: CurvedAnimation(parent: _a, curve: const Interval(0.45, 0.95, curve: Curves.easeInOutCubic)),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.md),
                    _fade(
                      0.5,
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.sm),
                        child: Column(children: [
                          row('Credit on resume', rupees(widget.credit), tone: C.success),
                          row('New switch-off date', _date(widget.newOff)),
                          row('TV', '${widget.tv} · VC ${widget.vc}'),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.6,
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, size: 16, color: C.muted),
                        const SizedBox(width: S.sm),
                        Expanded(
                          child: Text('Plans changed? Change the dates or cancel from Pause Connection any time before ${_short(widget.from)}.',
                              style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg), child: PrimaryButton(label: 'Done', onTap: _done)),
            ]),
          ),
          const Positioned.fill(child: Confetti()),
        ]),
      ),
    );
  }
}
