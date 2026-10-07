// Resolve on TV Error ("Diagnose an Issue"): point the phone at the TV and
// "Scan TV" reads the error on screen (simulated: a scan plays, then the
// error is named). No camera? The error code can be picked from a list.
// The error screen explains it and what to do; "Try This Fix" plays a short
// "Checking your connection" check and ends on a confirmation. "Contact
// Support" opens Contact Customer Support.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../recharge/recharge_screen.dart' show PaymentCheckScreen;
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'support_screen.dart' show ContactSupportScreen;

/// A TV error: code, name, what's going on, what to do, and what the fix
/// does while it runs.
class _TvError {
  const _TvError(this.code, this.title, this.about, this.steps, this.fixSteps);
  final String code;
  final String title;
  final String about;
  final List<String> steps;
  final List<String> fixSteps;
}

const _errors = [
  _TvError(
    '301',
    'Signal not found',
    'Your set-top box isn\'t receiving a signal. This usually happens due to a loose cable or a temporary service disruption.',
    [
      'Check that the cable between your set-top box and TV is firmly connected.',
      'Switch off your set-top box, wait 10 seconds, and switch it back on.',
      'Check for any outdoor dish obstruction such as rain or debris.',
    ],
    ['Reading your set-top box status', 'Sending a signal refresh', 'Confirming the signal is back'],
  ),
  _TvError(
    '101 / 102',
    'Channel not subscribed',
    'The channel you\'re trying to watch isn\'t being unlocked on your set-top box, even if it\'s part of your pack.',
    [
      'Make sure the channel is part of your pack.',
      'Keep your set-top box on channel 96 while we refresh it.',
      'Wait up to 15 minutes for the channels to come back.',
    ],
    ['Reading your set-top box status', 'Re-sending your channel rights', 'Unlocking your channels'],
  ),
  _TvError(
    '201',
    'Smart card not detected',
    'The set-top box can\'t read the smart card (VC). It may have moved or picked up dust.',
    [
      'Switch off the set-top box at the wall.',
      'Take the smart card out, wipe its gold chip with a dry cloth, and push it back in, chip facing down.',
      'Switch the box back on and wait a minute.',
    ],
    ['Reading your set-top box status', 'Pairing your smart card', 'Confirming the card is read'],
  ),
];

class TvErrorScreen extends StatefulWidget {
  const TvErrorScreen({super.key});

  @override
  State<TvErrorScreen> createState() => _TvErrorScreenState();
}

enum _Scan { idle, scanning, found }

class _TvErrorScreenState extends State<TvErrorScreen> {
  _Scan _scan = _Scan.idle;
  _TvError _found = _errors.first;
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _pickTv(AppStore app) async {
    final vc = await showSwitchTvSheet(context, title: 'Which TV shows the error?', subtitle: 'We\'ll diagnose one connection at a time.', anyTv: true);
    if (vc != null) app.selectVc(vc);
  }

  void _startScan(Connection c) {
    HapticFeedback.selectionClick();
    setState(() {
      _scan = _Scan.scanning;
      _found = _errors.first;
    });
    final still = MediaQuery.of(context).disableAnimations;
    _timers.add(Timer(Duration(milliseconds: still ? 600 : 2600), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _scan = _Scan.found);
    }));
    _timers.add(Timer(Duration(milliseconds: still ? 1200 : 3900), () {
      if (mounted) _show(c, _found);
    }));
  }

  Future<void> _show(Connection c, _TvError e) async {
    final self = ModalRoute.of(context);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ErrorScreen(c: c, error: e, back: self)));
    if (mounted) setState(() => _scan = _Scan.idle);
  }

  /// No camera handy: pick the code shown on the TV.
  Future<void> _pickCode(Connection c) async {
    final e = await showSheet<_TvError>(
      context,
      title: 'Which error do you see?',
      subtitle: 'The code is usually at the bottom of the TV screen.',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final e in _errors)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    color: C.danger.withValues(alpha: 0.12),
                    child: Text(e.code, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.danger)),
                  ),
                  const SizedBox(width: S.md),
                  Expanded(child: Text(e.title, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right_sharp, color: C.faint, size: 20),
                ]),
              ),
            ),
        ],
      ),
    );
    if (e != null && mounted) _show(c, e);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    if (c == null) return Scaffold(body: SafeArea(child: Column(children: const [Header(title: 'Diagnose an Issue')])));
    final busy = _scan != _Scan.idle;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Diagnose an Issue'),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
              child: InkWell(
                onTap: app.connections.length > 1 && !busy ? () => _pickTv(app) : null,
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
                Text('What\'s wrong with your TV?', style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Point your camera at your TV screen so we can identify the issue and help you fix it.',
                    style: T.body.copyWith(fontSize: 14, height: 1.5)),
                const SizedBox(height: S.lg),
                Reveal(child: _Viewfinder(state: _scan, error: _found)),
                const SizedBox(height: S.xl),
                Text('TIPS FOR A GOOD SCAN', style: T.overline),
                const SizedBox(height: S.sm),
                _tip(Icons.tv_sharp, 'Keep your TV switched on', 'Show the error message or blank screen as it is'),
                _tip(Icons.videocam_outlined, 'Fit the screen inside the frame', 'Hold your phone steady, about 1–2 m away'),
                const SizedBox(height: S.sm),
                Center(
                  child: TextButton(
                    onPressed: busy ? null : () => _pickCode(c),
                    child: BrandShade(
                      on: !busy,
                      child: Text('No camera? Choose the error code',
                          style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: busy ? C.faint : C.brand)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          BottomBar(
            child: PrimaryButton(
              label: busy ? 'Scanning…' : 'Scan TV',
              icon: Icons.videocam_outlined,
              onTap: busy ? null : () => _startScan(c),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tip(IconData icon, String title, String note) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 30, child: Icon(icon, size: 22, color: C.ink)),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(note, style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
            ]),
          ),
        ]),
      );
}

/// The camera frame: orange corner marks on a dark viewfinder. Ready, it
/// shows a camera; scanning, a TV outline with a line sweeping over it;
/// found, the error named in red.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.state, required this.error});
  final _Scan state;
  final _TvError error;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didUpdateWidget(_Viewfinder old) {
    super.didUpdateWidget(old);
    if (widget.state == _Scan.scanning && !MediaQuery.of(context).disableAnimations) {
      _sweep.repeat(reverse: true);
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    const ink = Color(0xFFF4F4F8);
    return Semantics(
      label: switch (s) {
        _Scan.idle => 'Camera ready',
        _Scan.scanning => 'Scanning your TV',
        _Scan.found => 'Error ${widget.error.code} detected',
      },
      liveRegion: true,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Container(
            color: const Color(0xFF0E1236),
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: _Corners())),
              if (s == _Scan.idle)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.videocam_outlined, size: 36, color: ink),
                    const SizedBox(height: S.sm),
                    Text('Camera ready', style: T.caption.copyWith(fontSize: 13, color: const Color(0xCCFFFFFF))),
                  ]),
                )
              else ...[
                Positioned(
                  top: S.lg,
                  left: 0,
                  right: 0,
                  child: Text(s == _Scan.found ? 'Issue identified' : 'Scanning your TV…',
                      textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 12.5, color: const Color(0xCCFFFFFF))),
                ),
                // The TV, with a sweeping line while scanning.
                Positioned.fill(
                  left: 56,
                  right: 56,
                  top: 48,
                  bottom: 64,
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (_, __) => CustomPaint(painter: _Tv(sweep: s == _Scan.scanning ? _sweep.value : null, found: s == _Scan.found)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: S.lg,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: c),
                      child: s == _Scan.found
                          ? Container(
                              key: const ValueKey('found'),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFD23C4C), border: Border.all(color: const Color(0x66FFFFFF))),
                              child: Text('Error ${widget.error.code} detected',
                                  style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            )
                          : const SizedBox(key: ValueKey('none'), height: 30),
                    ),
                  ),
                ),
              ],
              // Progress along the bottom edge while scanning.
              if (s != _Scan.idle)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: s == _Scan.found ? 1 : 0.85),
                    duration: Duration(milliseconds: s == _Scan.found ? 300 : 2600),
                    builder: (_, v, __) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(widthFactor: v, child: Container(height: 3, decoration: const BoxDecoration(gradient: G.brand))),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Orange corner marks around the frame.
class _Corners extends CustomPainter {
  const _Corners();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 18.0;
    const len = 26.0;
    final p = Paint()
      ..shader = G.brandInk.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final r = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    final path = Path()
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + len, r.top)
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + len)
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - len, r.bottom)
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - len);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Corners old) => false;
}

/// A TV seen by the camera: a screen of faint scanlines in an orange
/// outline, with a bright line sweeping down it while scanning.
class _Tv extends CustomPainter {
  _Tv({required this.sweep, required this.found});
  final double? sweep;
  final bool found;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(0, 0, size.width, size.height - 10);
    canvas.drawRect(screen, Paint()..color = const Color(0xFF14142A));
    final lines = Paint()..color = const Color(0x14FFFFFF);
    for (var y = screen.top + 4; y < screen.bottom; y += 5) {
      canvas.drawLine(Offset(screen.left, y), Offset(screen.right, y), lines);
    }
    canvas.drawRect(
      screen,
      Paint()
        ..color = found ? const Color(0xFFF07C88) : const Color(0xFFFF7A45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Stand.
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width / 2, size.height - 4), width: math.min(48, size.width / 4), height: 3),
        Paint()..color = const Color(0x55FFFFFF));
    final s = sweep;
    if (s != null) {
      final y = screen.top + screen.height * s;
      canvas.drawRect(
        Rect.fromLTRB(screen.left, y - 18, screen.right, y),
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FF7A45), Color(0x55FF7A45)])
              .createShader(Rect.fromLTRB(screen.left, y - 18, screen.right, y)),
      );
      canvas.drawLine(
          Offset(screen.left, y),
          Offset(screen.right, y),
          Paint()
            ..color = const Color(0xFFFF8A5B)
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_Tv old) => old.sweep != sweep || old.found != found;
}

// ---------------------------------------------------------------------------
// The error

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.c, required this.error, required this.back});
  final Connection c;
  final _TvError error;

  /// The Diagnose screen: the confirmation goes back past it.
  final Route<dynamic>? back;

  void _fix(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => PaymentCheckScreen(
        amount: 0,
        method: '',
        success: true,
        title: 'Checking your connection',
        icon: Icons.settings_input_antenna_sharp,
        subtitle: 'We\'re applying a recommended fix. This may take a few moments.',
        tag: '${c.label}  ·  VC ${c.vcPretty}',
        steps: error.fixSteps,
        onSuccess: () => _Fixed(c: c, error: error, back: back),
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Error Detected'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                Reveal(
                  child: Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: C.danger.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Icon(Icons.error_outline_sharp, size: 30, color: C.danger),
                    ),
                    const SizedBox(width: S.lg),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(error.title, style: T.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: C.danger.withValues(alpha: 0.14),
                          child: Text('ERROR ${error.code}', style: T.overline.copyWith(fontSize: 11.5, letterSpacing: 1, color: C.danger)),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: S.lg),
                Text(error.about, style: T.body.copyWith(fontSize: 14.5, height: 1.55)),
                const SizedBox(height: S.sm),
                Text('${c.label}  ·  VC ${c.vcPretty}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: S.xxl),
                Text('WHAT TO DO', style: T.overline),
                const SizedBox(height: S.sm),
                for (final (i, step) in error.steps.indexed)
                  Reveal(
                    order: i + 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(gradient: G.brand, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                        const SizedBox(width: S.md),
                        Expanded(
                            child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(step, style: T.body.copyWith(fontSize: 14.5, color: C.ink)))),
                      ]),
                    ),
                  ),
                const SizedBox(height: S.md),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 16, color: C.muted),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text('Done these? "Try This Fix" also sends a refresh to your set-top box from our side.',
                        style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                  ),
                ]),
              ],
            ),
          ),
          BottomBar(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrimaryButton(label: 'Try This Fix', icon: Icons.arrow_forward_sharp, onTap: () => _fix(context)),
              const SizedBox(height: S.sm),
              SecondaryButton(
                label: 'Contact Support',
                icon: Icons.headset_mic_outlined,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fixed

class _Fixed extends StatefulWidget {
  const _Fixed({required this.c, required this.error, required this.back});
  final Connection c;
  final _TvError error;
  final Route<dynamic>? back;

  @override
  State<_Fixed> createState() => _FixedState();
}

class _FixedState extends State<_Fixed> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final String _ref = 'SR${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// Back to Diagnose ([again]) or past it, to whatever opened it.
  void _leave({bool again = false}) {
    final nav = Navigator.of(context);
    final back = widget.back;
    if (back == null || !back.isActive) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    nav.popUntil((r) => r == back);
    if (!again && !back.isFirst) nav.pop();
  }

  Future<void> _stillThere() async {
    final next = await showSheet<String>(
      context,
      title: 'Still seeing the error?',
      subtitle: 'Some fixes take up to 15 minutes to reach your set-top box.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PrimaryButton(label: 'Scan the TV again', icon: Icons.videocam_outlined, onTap: () => Navigator.of(ctx).pop('scan')),
          const SizedBox(height: S.sm),
          SecondaryButton(label: 'Contact Support', icon: Icons.headset_mic_outlined, onTap: () => Navigator.of(ctx).pop('support')),
        ]),
      ),
    );
    if (!mounted || next == null) return;
    if (next == 'scan') {
      _leave(again: true);
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
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 40, S.page, S.xl),
                  children: [
                    // The TV coming back on: signal bars rise, then a tick.
                    Center(child: _BackOn(a: _a)),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.3,
                      Column(children: [
                        Text('Fix sent to your TV', textAlign: TextAlign.center, style: T.display.copyWith(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text('We sent a fix for "${widget.error.title}". Your channels should be back in a few minutes.', textAlign: TextAlign.center, style: T.body),
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
                      0.45,
                      Column(children: [
                        Container(height: 1, color: C.line),
                        row('Issue', '${widget.error.title} · Error ${widget.error.code}'),
                        row('Connection', '${c.label} · ${c.vcPretty}'),
                        row('Status', 'Signal restored'),
                        row('Fixed', 'Just now'),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PrimaryButton(label: 'Done', onTap: _leave),
                  TextButton(
                    onPressed: _stillThere,
                    child: BrandShade(
                        child: Text('Still seeing the error?', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand))),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A TV on the card gradient with signal bars that rise one by one, then a
/// green tick lands on its corner.
class _BackOn extends StatelessWidget {
  const _BackOn({required this.a});
  final Animation<double> a;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 130,
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: const Interval(0, 0.4, curve: Curves.elasticOut)),
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(gradient: G.brand),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.tv_sharp, color: Colors.white, size: 44),
                const SizedBox(height: 4),
                // Signal bars.
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedBuilder(
                      animation: a,
                      builder: (_, __) {
                        final t = Curves.easeOutBack.transform(((a.value - 0.3 - i * 0.08) / 0.2).clamp(0.0, 1.0));
                        return Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 5, height: (5 + i * 4) * t, color: Colors.white);
                      },
                    ),
                ]),
              ]),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 2,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: const Interval(0.6, 0.85, curve: Curves.elasticOut)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: C.success, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 3)),
                child: const Icon(Icons.check_sharp, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      );
}
