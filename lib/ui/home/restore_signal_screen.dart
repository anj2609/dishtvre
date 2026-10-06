// Signal Issue ("Restore Signal"): when subscribed channels won't play, pick
// the TV and we send a free refresh command to its set-top box. A short
// "Refreshing your service" check plays, then a confirmation with a
// reference ID. "Still not working?" lists what to try next, with a way to
// refresh again or get a technician. TVs a refresh can't fix (switched off,
// paused) say why and lead to Recharge or Vacation Mode instead.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../recharge/recharge_screen.dart' show PaymentCheckScreen, RechargeScreen;
import '../vacation/vacation_mode_screen.dart' show VacationModeScreen;
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'support_screen.dart' show ContactSupportScreen;

enum _Can { ok, off, paused }

_Can _can(Connection c) {
  if (c.status == ConnectionStatus.vacation) return _Can.paused;
  if (c.status == ConnectionStatus.deactivated || c.daysLeft(DateTime.now()) <= 0) return _Can.off;
  return _Can.ok;
}

class RestoreSignalScreen extends StatefulWidget {
  const RestoreSignalScreen({super.key});

  @override
  State<RestoreSignalScreen> createState() => _RestoreSignalScreenState();
}

class _RestoreSignalScreenState extends State<RestoreSignalScreen> {
  String? _vc;
  final _cards = <String, GlobalKey>{};

  void _tap(AppStore app, Connection c) {
    switch (_can(c)) {
      case _Can.off:
        app.selectVc(c.vc);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen()));
      case _Can.paused:
        app.selectVc(c.vc);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VacationModeScreen()));
      case _Can.ok:
        HapticFeedback.selectionClick();
        setState(() => _vc = c.vc);
        // Keep the picked card clear of the button that slides up.
        Future.delayed(const Duration(milliseconds: 300), () {
          final ctx = _cards[c.vc]?.currentContext;
          if (!mounted || ctx == null || !ctx.mounted) return;
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        });
    }
  }

  Future<void> _refresh(Connection c, String location) async {
    final self = ModalRoute.of(context);
    await Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: 0,
        method: '',
        success: true,
        title: 'Refreshing your service',
        icon: Icons.refresh_sharp,
        subtitle: 'We\'re sending a refresh signal to your set-top box. This may take a few moments.',
        tag: '${c.label}  ·  VC ${c.vcPretty}',
        steps: const ['Connecting to your set-top box', 'Sending the refresh signal', 'Restoring your channels'],
        onSuccess: () => _Refreshed(c: c, location: location, back: self),
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final tvs = app.connections;
    final location = app.subscriber?.address.city ?? '';
    final sel = tvs.where((c) => c.vc == _vc && _can(c) == _Can.ok).firstOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Restore Signal'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                const Reveal(child: _Hero()),
                const SizedBox(height: S.xl),
                Text('BEFORE YOU REFRESH', style: T.overline),
                const SizedBox(height: S.sm),
                _step(1, 'Getting ', 'error 101 / 102', ' on your TV? Choose that connection below.'),
                _step(2, 'The channel you can\'t watch should be ', 'part of your pack', '.'),
                _step(3, 'Keep your set-top box ', 'ON at channel no. 96', ' for the next 15 minutes.'),
                Container(height: 1, margin: const EdgeInsets.symmetric(vertical: S.lg), color: C.line),
                Text('CHOOSE A CONNECTION', style: T.overline),
                const SizedBox(height: S.md),
                for (final (i, c) in tvs.indexed) ...[
                  Reveal(
                    order: i + 1,
                    child: _TvCard(
                      key: _cards.putIfAbsent(c.vc, GlobalKey.new),
                      c: c,
                      location: location,
                      can: _can(c),
                      selected: sel?.vc == c.vc,
                      onTap: () => _tap(app, c),
                    ),
                  ),
                  const SizedBox(height: S.md),
                ],
              ],
            ),
          ),
          // Slides up once a TV is picked.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, a) => SizeTransition(
              sizeFactor: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: a, child: child),
            ),
            child: sel == null
                ? SizedBox(key: const ValueKey('none'), width: double.infinity, height: MediaQuery.paddingOf(context).bottom)
                : BottomBar(
                    key: const ValueKey('go'),
                    child: PrimaryButton(label: 'Refresh Signal', icon: Icons.refresh_sharp, onTap: () => _refresh(sel, location)),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _step(int n, String a, String b, String c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.brand.withValues(alpha: 0.14)),
            child: BrandShade(child: Text('$n', style: T.label.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: C.brand))),
          ),
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

/// What this does, on the card gradient.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(gradient: G.brand),
        child: Stack(children: [
          const Positioned.fill(child: GlossSweep()),
          Padding(
            padding: const EdgeInsets.all(S.lg + 2),
            child: Row(children: [
              Container(width: 50, height: 50, color: const Color(0x29FFFFFF), child: const Icon(Icons.refresh_sharp, color: Colors.white, size: 26)),
              const SizedBox(width: S.md + 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Not able to watch subscribed channels?', style: T.title.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('We\'ll send a refresh command to your set-top box. It\'s free.',
                      style: T.caption.copyWith(fontSize: 12.5, height: 1.45, color: const Color(0xD9FFFFFF))),
                ]),
              ),
            ]),
          ),
        ]),
      );
}

/// A TV: name, VC and pack, and where it is. Picked, it gets the gradient
/// edge; one a refresh can't help says why and where to go instead.
class _TvCard extends StatelessWidget {
  const _TvCard({super.key, required this.c, required this.location, required this.can, required this.selected, required this.onTap});
  final Connection c;
  final String location;
  final _Can can;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = switch (can) {
      _Can.off => ('Switched off. A refresh won\'t help; recharge to switch it on.', 'Recharge', C.danger),
      _Can.paused => ('Paused for vacation, so channels are off on purpose.', 'Vacation Mode', C.info),
      _Can.ok => null,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${c.label}, VC ${c.vcPretty}, ${c.planName}${note == null ? '' : '. ${note.$1}'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(gradient: selected ? G.brandInk : null, color: selected ? null : C.surface),
        child: Material(
          color: C.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.lg, S.md + 2, S.lg, S.md + 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('VC ${c.vcPretty}  ·  ${c.planName}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                    ]),
                  ),
                  const SizedBox(width: S.sm),
                  if (location.isNotEmpty) Text(location, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.inkSoft)),
                ]),
                if (note != null) ...[
                  const SizedBox(height: S.sm),
                  Row(children: [
                    Expanded(child: Text(note.$1, style: T.caption.copyWith(fontSize: 12, color: note.$3))),
                    const SizedBox(width: S.sm),
                    BrandShade(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(note.$2, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand)),
                        Icon(Icons.chevron_right_sharp, size: 17, color: C.brand),
                      ]),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Done

class _Refreshed extends StatefulWidget {
  const _Refreshed({required this.c, required this.location, required this.back});
  final Connection c;
  final String location;

  /// The Restore Signal screen, for "Try again" (and Done goes past it).
  final Route<dynamic>? back;

  @override
  State<_Refreshed> createState() => _RefreshedState();
}

class _RefreshedState extends State<_Refreshed> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  late final String _ref = 'RS${DateTime.now().millisecondsSinceEpoch % 100000000}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// Back to the Restore Signal screen; [past] goes one further, to the
  /// screen that opened it.
  void _leave({bool past = false}) {
    final nav = Navigator.of(context);
    final back = widget.back;
    if (back == null || !back.isActive) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    nav.popUntil((r) => r == back);
    if (past && !back.isFirst) nav.pop();
  }

  Future<void> _stillBroken() async {
    final next = await showSheet<String>(
      context,
      title: 'Still not working?',
      subtitle: 'Give it a few minutes first. Then try these.',
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (icon, text) in const [
            (Icons.power_settings_new_sharp, 'Switch the set-top box off at the wall, wait 30 seconds, and switch it on again.'),
            (Icons.cable_sharp, 'Check the cable from the dish is pushed in firmly at the back of the box.'),
            (Icons.tv_sharp, 'Leave the box on channel 96 for 15 minutes so the refresh can reach it.'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 20, color: C.ink),
                const SizedBox(width: S.md),
                Expanded(child: Text(text, style: T.body.copyWith(fontSize: 14))),
              ]),
            ),
          const SizedBox(height: S.lg),
          PrimaryButton(label: 'Refresh again', icon: Icons.refresh_sharp, onTap: () => Navigator.of(ctx).pop('again')),
          const SizedBox(height: S.sm),
          SecondaryButton(label: 'Request a technician', icon: Icons.engineering_outlined, onTap: () => Navigator.of(ctx).pop('tech')),
        ]),
      ),
    );
    if (!mounted || next == null) return;
    if (next == 'again') {
      _leave();
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen()));
    }
  }

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.3).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    Widget row(String a, String b) => Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Text(a, style: T.body.copyWith(fontSize: 14.5, color: C.muted)),
            const SizedBox(width: S.lg),
            Expanded(child: Text(b, textAlign: TextAlign.end, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700))),
          ]),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(past: true);
      },
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 40, S.page, S.xl),
                  children: [
                    // The badge, with a soft ring of light pulsing out once.
                    Center(
                      child: SizedBox(
                        width: 160,
                        height: 140,
                        child: Stack(alignment: Alignment.center, children: [
                          AnimatedBuilder(
                            animation: _a,
                            builder: (_, __) {
                              final t = Curves.easeOut.transform((_a.value / 0.7).clamp(0.0, 1.0));
                              return Container(
                                width: 90 + 60 * t,
                                height: 90 + 60 * t,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: C.brand.withValues(alpha: 0.18 * (1 - t))),
                              );
                            },
                          ),
                          ScaleTransition(
                            scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.45, curve: Curves.elasticOut)),
                            child: RotationTransition(
                              turns:
                                  Tween(begin: -0.15, end: 0.0).animate(CurvedAnimation(parent: _a, curve: const Interval(0, 0.5, curve: Curves.easeOutBack))),
                              // White behind the badge so its cut-out tick shows white.
                              child: Stack(alignment: Alignment.center, children: [
                                Container(width: 56, height: 56, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                BrandShade(child: Icon(Icons.verified_sharp, size: 112, color: C.brand)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.md),
                    _fade(
                      0.25,
                      Column(children: [
                        Text('Your service has been refreshed', textAlign: TextAlign.center, style: T.display.copyWith(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text('Please wait a moment and check your TV.', textAlign: TextAlign.center, style: T.body),
                        const SizedBox(height: S.md),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: C.surface,
                          child: Text('Ref ID  ·  $_ref', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: C.inkSoft)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.4,
                      Column(children: [
                        Container(height: 1, color: C.line),
                        row('Connection', c.label),
                        row('VC No.', c.vcPretty),
                        if (widget.location.isNotEmpty) row('Location', widget.location),
                        row('Refresh sent', 'Just now'),
                      ]),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.55,
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, size: 16, color: C.muted),
                        const SizedBox(width: S.sm),
                        Expanded(
                          child: Text('Keep the set-top box on channel 96 for the next 15 minutes so the refresh can reach it.',
                              style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PrimaryButton(label: 'Done', onTap: () => _leave(past: true)),
                  TextButton(
                    onPressed: _stillBroken,
                    child: BrandShade(child: Text('Still not working?', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand))),
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
