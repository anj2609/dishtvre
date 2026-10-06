// Pay Later: three more days of TV now, with a ₹10 service charge added to
// the next recharge. Pick a TV and avail it; a short "Activating Pay Later"
// check plays, then a success screen shows the extra days on a calendar
// strip and what the next recharge will be. TVs that are paused, already on
// Pay Later, or still have plenty of days left can't be picked, and each
// says why.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'recharge_screen.dart' show PaymentCheckScreen, RechargeScreen;

const _extraDays = 3;
const _charge = 10.0;

/// Pay Later opens this many days before the switch-off date.
const _window = 7;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';
String _long(DateTime d) => '${_dayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// TVs that have used Pay Later this cycle, kept while the app is open.
final payLaterUsed = ValueNotifier<Set<String>>({});

enum _Why { ok, inUse, paused, early }

_Why _why(Connection c) {
  if (payLaterUsed.value.contains(c.vc)) return _Why.inUse;
  if (c.status == ConnectionStatus.vacation) return _Why.paused;
  if (c.daysLeft(DateTime.now()) > _window) return _Why.early;
  return _Why.ok;
}

bool _isOff(Connection c) => c.daysLeft(DateTime.now()) <= 0;

/// Where the extra days start: the switch-off date, or today for a TV
/// that has already switched off.
DateTime _from(Connection c) => _isOff(c) ? _day(DateTime.now()) : _day(c.switchOffDate);

String _kind(Connection c) => switch (c.type) {
      ConnectionType.parent => 'Main TV · Multi TV',
      ConnectionType.child => 'Multi TV',
      ConnectionType.individual => 'Single TV',
    };

class PayLaterScreen extends StatefulWidget {
  const PayLaterScreen({super.key});

  @override
  State<PayLaterScreen> createState() => _PayLaterScreenState();
}

class _PayLaterScreenState extends State<PayLaterScreen> {
  String? _vc;
  final _cards = <String, GlobalKey>{};

  void _pick(Connection c) {
    HapticFeedback.selectionClick();
    setState(() => _vc = c.vc);
    // Once the card has opened and the bar has slid up, keep the whole card
    // in view above the bar.
    Future.delayed(const Duration(milliseconds: 300), () {
      final ctx = _cards[c.vc]?.currentContext;
      if (!mounted || ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    });
  }

  Future<void> _avail(AppStore app, Connection c) async {
    final wasOff = _isOff(c);
    final from = _from(c);
    await Navigator.of(context).push<bool>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: 0,
        method: '',
        success: true,
        title: 'Activating Pay Later',
        icon: Icons.more_time_sharp,
        subtitle: '$_extraDays extra days for ${c.label}  ·  ₹0 now',
        steps: [
          'Checking ${c.label} can use Pay Later',
          'Adding $_extraDays days to your pack',
          wasOff ? 'Switching your TV back on' : 'Moving your switch-off date'
        ],
        onSuccess: () {
          final off = app.extendSwitchOff(c.vc, _extraDays);
          payLaterUsed.value = {...payLaterUsed.value, c.vc};
          app.selectVc(c.vc);
          return _PayLaterSuccess(tv: c.label, vc: c.vcPretty, from: from, off: off, wasOff: wasOff, next: c.monthlyRecharge + _charge);
        },
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  /// Recharge for a TV that can't use Pay Later (or already has).
  void _recharge(AppStore app, Connection c) {
    app.selectVc(c.vc);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: payLaterUsed,
      builder: (context, _, __) {
        final tvs = app.connections;
        // A TV is always picked while any can use Pay Later: the one tapped,
        // else the TV picked across the app, else the first that can.
        final open = tvs.where((c) => _why(c) == _Why.ok).toList();
        final sel = open.where((c) => c.vc == _vc).firstOrNull ?? open.where((c) => c.vc == app.connection?.vc).firstOrNull ?? open.firstOrNull;
        // With none left, the bar offers a recharge for the TV that switches
        // off soonest.
        final soonest = ([...tvs]..sort((a, b) => a.switchOffDate.compareTo(b.switchOffDate))).firstOrNull;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              const Header(title: 'Pay Later'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
                  children: [
                    const Reveal(child: _Hero()),
                    const SizedBox(height: S.xxl),
                    Text('CHOOSE A CONNECTION', style: T.overline),
                    const SizedBox(height: S.md),
                    for (final (i, c) in tvs.indexed) ...[
                      Reveal(
                        order: i + 1,
                        child: _TvCard(
                            key: _cards.putIfAbsent(c.vc, GlobalKey.new),
                            c: c,
                            why: _why(c),
                            selected: sel?.vc == c.vc,
                            onTap: () => _why(c) == _Why.ok ? _pick(c) : _recharge(app, c)),
                      ),
                      const SizedBox(height: S.md),
                    ],
                    const SizedBox(height: S.sm),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline, size: 16, color: C.muted),
                      const SizedBox(width: S.sm),
                      Expanded(
                        child: Text(
                          'Pay Later can be used once per recharge, in the last $_window days before switch-off or after your TV switches off.',
                          style: T.caption.copyWith(fontSize: 12, color: C.muted),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              // Avail Now for the picked TV; with none that can, a recharge.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, a) => SizeTransition(
                  sizeFactor: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                  alignment: Alignment.topCenter,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: sel == null
                    ? BottomBar(
                        key: const ValueKey('recharge'),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('No TV needs Pay Later now', style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              if (soonest != null)
                                Text('${soonest.label} switches off on ${_short(soonest.switchOffDate)}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                            ]),
                          ),
                          const SizedBox(width: S.md),
                          SizedBox(
                            width: 150,
                            child: PrimaryButton(label: 'Recharge', onTap: soonest == null ? null : () => _recharge(app, soonest)),
                          ),
                        ]),
                      )
                    : BottomBar(
                        key: const ValueKey('avail'),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('₹0 to pay now', style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${rupees(_charge)} with the next recharge',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                            ]),
                          ),
                          const SizedBox(width: S.md),
                          SizedBox(width: 150, child: PrimaryButton(label: 'Avail Now', onTap: () => _avail(app, sel))),
                        ]),
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// The offer on the card gradient: three days, ₹0 now, ₹10 later.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: T.price.copyWith(fontSize: 19, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 11.5, color: const Color(0xCCFFFFFF))),
          ]),
        );
    Widget rule() => Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.md), color: const Color(0x40FFFFFF));
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(gradient: G.brand),
      child: Stack(children: [
        // A big faint "+3" behind the text.
        Positioned(
          right: -8,
          top: -14,
          child: ExcludeSemantics(
            child:
                Text('+$_extraDays', style: T.display.copyWith(fontSize: 100, fontWeight: FontWeight.w800, letterSpacing: -5, color: const Color(0x17FFFFFF))),
          ),
        ),
        const Positioned.fill(child: GlossSweep()),
        Padding(
          padding: const EdgeInsets.all(S.lg + 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46,
                height: 46,
                color: const Color(0x29FFFFFF),
                child: const Icon(Icons.more_time_sharp, color: Colors.white, size: 24),
              ),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enjoy TV for $_extraDays extra days', style: T.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'A ${rupees(_charge)} service charge is added to your next recharge. No payment needed right now.',
                    style: T.caption.copyWith(fontSize: 12.5, height: 1.45, color: const Color(0xD9FFFFFF)),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: S.lg + 2),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                stat('$_extraDays days', 'extra TV'),
                rule(),
                stat('₹0', 'to pay now'),
                rule(),
                stat(rupees(_charge), 'on next recharge'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// One TV: name, VC, days left, when to recharge and how much. Picked, it
/// gets a gradient edge and shows what Pay Later changes.
class _TvCard extends StatelessWidget {
  const _TvCard({super.key, required this.c, required this.why, required this.selected, required this.onTap});
  final Connection c;
  final _Why why;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = c.daysLeft(DateTime.now());
    final off = left <= 0;
    final can = why == _Why.ok;
    final (status, tone) = switch (why) {
      _Why.inUse => ('Pay Later on', C.success),
      _Why.paused => ('Paused', C.muted),
      _ when off => ('Switched off', C.danger),
      _ => (left == 1 ? '1 day left' : '$left days left', left <= 5 ? C.danger : C.success),
    };
    final note = switch (why) {
      _Why.inUse => 'On Pay Later till ${_short(c.switchOffDate)}. Recharge before then to keep watching.',
      _Why.paused => 'Paused for vacation, so it doesn\'t need Pay Later.',
      _Why.early => 'Opens on ${_short(_day(c.switchOffDate).subtract(const Duration(days: _window)))}, a week before switch-off.',
      _Why.ok => null,
    };
    final next = c.monthlyRecharge + (why == _Why.inUse ? _charge : 0);
    const indent = 20.0 + S.md;

    Widget figure(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
          const SizedBox(height: 3),
          Text(value, style: T.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        ]);

    return Semantics(
      button: true,
      selected: selected,
      label: '${c.label}, VC ${c.vcPretty}, $status${can ? '' : '. Recharge now'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(gradient: selected ? G.brandInk : null, color: selected ? null : C.surface),
        child: Material(
          color: C.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, S.lg),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Mark(why: why, selected: selected),
                    const SizedBox(width: S.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('VC ${c.vcPretty}  ·  ${_kind(c)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                      ]),
                    ),
                    const SizedBox(width: S.sm),
                    Text(status, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone)),
                  ]),
                  const SizedBox(height: S.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: indent),
                    child: Row(children: [
                      figure(off && why != _Why.inUse ? 'Switched off on' : 'Recharge by', _short(c.switchOffDate)),
                      const SizedBox(width: S.xxl),
                      figure(why == _Why.inUse ? 'Next recharge' : 'Recharge', rupees(next)),
                    ]),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: S.md),
                    Padding(
                      padding: const EdgeInsets.only(left: indent),
                      child: Text(note, style: T.caption.copyWith(fontSize: 12, color: C.inkSoft)),
                    ),
                    // Where to go instead: the card itself opens Recharge.
                    const SizedBox(height: S.sm),
                    Padding(
                      padding: const EdgeInsets.only(left: indent),
                      child: BrandShade(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Recharge now', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: C.brand)),
                          Icon(Icons.chevron_right_sharp, size: 18, color: C.brand),
                        ]),
                      ),
                    ),
                  ],
                  // What Pay Later changes, once this TV is picked.
                  if (selected) ...[
                    const SizedBox(height: S.md),
                    Container(
                      margin: const EdgeInsets.only(left: indent),
                      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm + 2),
                      color: const Color(0x1AFF6A3D),
                      child: Row(children: [
                        BrandShade(child: Icon(Icons.more_time_sharp, size: 18, color: C.brand)),
                        const SizedBox(width: S.sm),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text.rich(
                              TextSpan(style: T.caption.copyWith(fontSize: 12.5, color: C.inkSoft), children: [
                                TextSpan(text: off ? 'Back on now, till ' : 'Switch-off moves to '),
                                TextSpan(
                                  text: _short(_from(c).add(const Duration(days: _extraDays))),
                                  style: T.caption.copyWith(fontSize: 12.5, color: C.ink, fontWeight: FontWeight.w700),
                                ),
                              ]),
                            ),
                            Text('Next recharge ${rupees(c.monthlyRecharge + _charge)}', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pick mark: a ring, filled with the gradient once picked; a green
/// check for a TV already on Pay Later; a pause or clock for one that can't
/// use it yet.
class _Mark extends StatelessWidget {
  const _Mark({required this.why, required this.selected});
  final _Why why;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (why == _Why.inUse) return Icon(Icons.check_circle_sharp, size: 20, color: C.success);
    if (why == _Why.paused) return Icon(Icons.pause_circle_outline_sharp, size: 20, color: C.muted);
    if (why == _Why.early) return Icon(Icons.schedule_sharp, size: 20, color: C.muted);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? G.brand : null,
        border: selected ? null : Border.all(color: C.lineStrong, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check_sharp, size: 14, color: Colors.white) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Success

class _PayLaterSuccess extends StatefulWidget {
  const _PayLaterSuccess({required this.tv, required this.vc, required this.from, required this.off, required this.wasOff, required this.next});
  final String tv;
  final String vc;

  /// First of the extra days.
  final DateTime from;

  /// The new switch-off date.
  final DateTime off;
  final bool wasOff;

  /// What the next recharge will be, service charge included.
  final double next;

  @override
  State<_PayLaterSuccess> createState() => _PayLaterSuccessState();
}

class _PayLaterSuccessState extends State<_PayLaterSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _recharge() => Navigator.of(context)
    ..popUntil((r) => r.isFirst)
    ..push(MaterialPageRoute(builder: (_) => const RechargeScreen()));

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.35).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String a, String b, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted)),
            const SizedBox(width: S.md),
            Expanded(
              child: Text(b,
                  textAlign: TextAlign.end, style: T.label.copyWith(fontSize: strong ? 15.5 : 14, fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
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
                  padding: const EdgeInsets.fromLTRB(S.page, 40, S.page, S.xl),
                  children: [
                    Center(child: _DaysBadge(a: _a)),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.3,
                      Column(children: [
                        Text(widget.wasOff ? '${widget.tv} is back on' : '$_extraDays extra days added', textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(style: T.body, children: [
                            TextSpan(text: '${widget.tv} now switches off on '),
                            TextSpan(text: _long(widget.off), style: T.body.copyWith(color: C.ink, fontWeight: FontWeight.w700)),
                            const TextSpan(text: '. Recharge before then to keep watching.'),
                          ]),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                    const SizedBox(height: S.xxl),
                    _fade(0.42, _Strip(a: _a, from: widget.from)),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.58,
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.sm),
                        child: Column(children: [
                          row('TV', '${widget.tv} · VC ${widget.vc}'),
                          row('Paid now', '₹0'),
                          row('Service charge', '${rupees(_charge)} on next recharge'),
                          row('Next recharge', rupees(widget.next), strong: true),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.68,
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, size: 16, color: C.muted),
                        const SizedBox(width: S.sm),
                        Expanded(
                          child: Text('Pay Later can be used again after your next recharge.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PrimaryButton(label: 'Done', onTap: _done),
                  const SizedBox(height: S.xs),
                  TextButton(
                    onPressed: _recharge,
                    child:
                        BrandShade(child: Text('Recharge now instead', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand))),
                  ),
                ]),
              ),
            ]),
          ),
          const Positioned.fill(child: Confetti()),
        ]),
      ),
    );
  }
}

/// A sharp calendar page on the card gradient that counts up to "+3".
class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.a});
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(parent: a, curve: const Interval(0, 0.4, curve: Curves.elasticOut));
    final count = CurvedAnimation(parent: a, curve: const Interval(0.12, 0.5, curve: Curves.easeOutCubic));
    return Semantics(
      label: '$_extraDays extra days',
      child: ExcludeSemantics(
        child: ScaleTransition(
          scale: pop,
          child: Container(
            width: 116,
            height: 124,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(gradient: G.brand),
            child: Stack(children: [
              Column(children: [
                // The calendar's binding strip, with two rings.
                Container(
                  height: 26,
                  color: const Color(0x33000000),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    for (var i = 0; i < 2; i++) Container(width: 6, height: 12, color: const Color(0xCCFFFFFF)),
                  ]),
                ),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedBuilder(
                      animation: count,
                      builder: (_, __) => Text(
                        '+${(count.value * _extraDays).round()}',
                        style: T.display.copyWith(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('DAYS', style: T.overline.copyWith(fontSize: 11, letterSpacing: 2, color: const Color(0xD9FFFFFF))),
                  ]),
                ),
              ]),
              const Positioned.fill(child: GlossSweep(delay: Duration(milliseconds: 700))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A week around the extra days: the three extra days fill in with the
/// gradient one after another, and the new switch-off day is outlined.
class _Strip extends StatelessWidget {
  const _Strip({required this.a, required this.from});
  final Animation<double> a;
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final start = from.subtract(const Duration(days: 2));
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final last = from.add(const Duration(days: _extraDays - 1));
    final off = from.add(const Duration(days: _extraDays));
    final today = _day(DateTime.now());
    Widget key(Widget swatch, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          swatch,
          const SizedBox(width: 6),
          Text(label, style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
        ]);
    return Semantics(
      label: 'Extra days ${_short(from)} to ${_short(last)}. New switch-off ${_short(off)}.',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Your extra days', style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
            Text('${_short(from)} – ${_short(last)}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
          ]),
          const SizedBox(height: S.md),
          Row(children: [
            for (final (i, d) in days.indexed) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: _cell(d, extra: !d.isBefore(from) && !d.isAfter(last), isOff: d == off, isToday: d == today, order: i - 2)),
            ],
          ]),
          const SizedBox(height: S.md),
          Wrap(spacing: S.lg, runSpacing: S.xs, children: [
            key(Container(width: 10, height: 10, decoration: const BoxDecoration(gradient: G.brand)), 'Extra days'),
            key(Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: C.inkSoft, width: 1.5))), 'New switch-off'),
          ]),
        ]),
      ),
    );
  }

  Widget _cell(DateTime d, {required bool extra, required bool isOff, required bool isToday, required int order}) {
    final fill = CurvedAnimation(parent: a, curve: Interval((0.5 + order * 0.08).clamp(0, 1), (0.66 + order * 0.08).clamp(0, 1), curve: Curves.easeOutBack));
    final number =
        Text('${d.day}', style: T.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: extra ? Colors.white : (isOff ? C.ink : C.muted)));
    return Column(children: [
      Text(isToday ? 'Today' : _dayNames[d.weekday - 1],
          maxLines: 1, style: T.caption.copyWith(fontSize: 10.5, color: isToday ? C.ink : C.muted, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
      const SizedBox(height: 6),
      SizedBox(
        height: 50,
        child: Stack(fit: StackFit.expand, children: [
          Container(
            decoration: BoxDecoration(
              color: C.surface,
              border: isOff ? Border.all(color: C.inkSoft, width: 1.5) : null,
            ),
          ),
          if (extra) ScaleTransition(scale: fill, child: Container(decoration: const BoxDecoration(gradient: G.brand))),
          Center(
              child: isOff
                  ? Column(mainAxisSize: MainAxisSize.min, children: [number, Icon(Icons.power_settings_new_sharp, size: 11, color: C.inkSoft)])
                  : number),
        ]),
      ),
    ]);
  }
}
