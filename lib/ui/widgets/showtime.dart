// Showtime effects: the small touches that make the app feel like
// entertainment rather than a bill. A soft glow, gliding channel logos,
// cards that press in, staggered entrances and confetti.
//
// All motion stops when the system asks for reduced motion (and in tests).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import 'widgets.dart';

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A lifted card filled with a solid colour: [color] blended into the card
/// shade by [strength] (1 = the colour itself).
class Glow extends StatelessWidget {
  const Glow({
    super.key,
    required this.child,
    this.color,
    this.at = Alignment.topRight,
    this.strength = 0.16,
    this.radius = R.xl,
  });

  final Widget child;

  /// Defaults to the accent.
  final Color? color;
  final Alignment at;
  final double strength;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? C.brand;
    final fill = Color.lerp(C.cardTop, color, strength)!;
    final edge = strength >= 1 ? Color.lerp(color, Colors.black, 0.25)! : Color.lerp(C.cardEdge, color, strength)!;
    return Container(
      decoration: BoxDecoration(color: fill, border: Border.all(color: edge), boxShadow: D.lift),
      child: child,
    );
  }
}

/// Fades the left and right edges of a strip into the background.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.child, this.width = 0.12});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, width, 1 - width, 1],
        ).createShader(r),
        child: child,
      );
}

/// An endless row of channel logos gliding sideways. Decorative.
class LogoMarquee extends StatefulWidget {
  const LogoMarquee({super.key, required this.logos, this.size = 44, this.gap = 10, this.speed = 22, this.reverse = false, this.ring, this.outline = false, this.square = false});

  /// (channel name, logo url)
  final List<(String, String?)> logos;
  final double size;
  final double gap;

  /// Logical pixels per second.
  final double speed;
  final bool reverse;
  final Color? ring;

  /// App icons (square) instead of channel logos (round).
  final bool square;

  /// Hairline edge on each logo, for light backgrounds.
  final bool outline;

  @override
  State<LogoMarquee> createState() => _LogoMarqueeState();
}

class _LogoMarqueeState extends State<LogoMarquee> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: _period);

  double get _span => widget.logos.length * (widget.size + widget.gap);
  Duration get _period => Duration(milliseconds: math.max(1, (_span / widget.speed * 1000).round()));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context) || widget.logos.isEmpty) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void didUpdateWidget(LogoMarquee old) {
    super.didUpdateWidget(old);
    if (old.logos.length != widget.logos.length) {
      _t.duration = _period;
      if (!_still(context) && widget.logos.isNotEmpty) _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logos.isEmpty) return SizedBox(height: widget.size);
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      for (final l in [...widget.logos, ...widget.logos, ...widget.logos])
        Padding(
          padding: EdgeInsets.only(right: widget.gap),
          child: widget.square
              ? AppLogo(name: l.$1, url: l.$2, size: widget.size)
              : ChannelLogo(name: l.$1, url: l.$2, size: widget.size, ring: widget.ring, outline: widget.outline),
        ),
    ]);
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.size,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, child) {
              final dx = (widget.reverse ? _t.value - 1 : -_t.value) * _span;
              return Stack(clipBehavior: Clip.none, children: [Positioned(left: dx, top: 0, bottom: 0, child: child!)]);
            },
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Shrinks a touch while pressed, then springs back.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.label});

  final Widget child;
  final VoidCallback onTap;

  /// Screen-reader label; when null the child's own semantics are used.
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Pressing tips the card back a little, like pushing a real tile.
    Widget child = TweenAnimationBuilder<double>(
      tween: Tween(end: _down ? 1 : 0),
      duration: Duration(milliseconds: _down ? 110 : 260),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      builder: (_, v, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(0.07 * v)
          ..scale(1 - 0.025 * v),
        child: child,
      ),
      child: widget.child,
    );
    if (widget.label != null) child = ExcludeSemantics(child: child);
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: child,
      ),
    );
  }
}

/// Fades and lifts its child into place; [order] staggers siblings.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.order = 0});

  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return child;
    final delay = 70.0 * order;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total.round()),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// A short burst of confetti from the top of its box. Plays once.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  final _bits = List.generate(40, (i) => _Bit(math.Random(i * 7919)));

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_still(context) && _t.status == AnimationStatus.dismissed) _t.forward();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return const SizedBox.shrink();
    return IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_t, _bits), size: Size.infinite));
  }
}

class _Bit {
  _Bit(math.Random r)
      : x = r.nextDouble(),
        drift = (r.nextDouble() - 0.5) * 0.5,
        speed = 0.7 + r.nextDouble() * 0.6,
        spin = (r.nextDouble() - 0.5) * 14,
        size = 5 + r.nextDouble() * 6,
        delay = r.nextDouble() * 0.25,
        color = [C.brand, Color(0xFFFF9B78), C.inkSoft, C.violet, Color(0xFFE2B45A), C.muted][r.nextInt(6)];

  final double x, drift, speed, spin, size, delay;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits) : super(repaint: t);

  final Animation<double> t;
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final p = ((t.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = -20 + (size.height * 0.9) * b.speed * Curves.easeIn.transform(p);
      final x = size.width * (b.x + b.drift * p) + math.sin(p * 9 + b.spin) * 12;
      final fade = p > 0.75 ? (1 - p) / 0.25 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55), Radius.zero),
        Paint()..color = b.color.withAlpha((255 * fade).round()),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

/// Round icon button for dark stages.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.label, required this.onTap, this.badge = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: C.glass,
        shape: CircleBorder(side: BorderSide(color: C.glassLine)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: 21, color: C.onNight),
              if (badge)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(gradient: G.brand, shape: BoxShape.circle, border: Border.all(color: C.night, width: 1.5)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Up to [n] channels with logos, taking turns across genres so a strip of
/// logos shows the variety in a pack.
List<(String, String?)> showcase(List<Channel> channels, int n) {
  final byGenre = <String, List<Channel>>{};
  final seen = <String>{};
  for (final c in channels) {
    if (c.logoUrl == null || !seen.add(c.logoUrl!)) continue;
    byGenre.putIfAbsent(c.genre, () => []).add(c);
  }
  final out = <(String, String?)>[];
  for (var i = 0; out.length < n; i++) {
    var any = false;
    for (final l in byGenre.values) {
      if (i < l.length && out.length < n) {
        out.add((l[i].name, l[i].logoUrl));
        any = true;
      }
    }
    if (!any) break;
  }
  return out;
}

/// Glass gloss for a card: a faint diagonal reflection, plus one soft band
/// of light that sweeps across shortly after the card appears. Decorative.
class GlossSweep extends StatefulWidget {
  const GlossSweep({super.key, this.delay = const Duration(milliseconds: 350)});

  final Duration delay;

  @override
  State<GlossSweep> createState() => _GlossSweepState();
}

class _GlossSweepState extends State<GlossSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _t.value = 1;
    } else if (_t.status == AnimationStatus.dismissed) {
      Future.delayed(widget.delay, () {
        if (mounted) _t.forward();
      });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(painter: _GlossPainter(_t), size: Size.infinite),
        ),
      );
}

class _GlossPainter extends CustomPainter {
  _GlossPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The still reflection: a broad, faint diagonal band across the top-left.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          stops: [0, 0.28, 0.42, 1],
          colors: [Color(0x0FFFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    // The sweep: a narrow band of light travelling left to right once.
    final v = Curves.easeInOutCubic.transform(t.value);
    if (v <= 0 || v >= 1) return;
    final x = -0.6 + 2.2 * v;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(x * 2 - 1 - 0.5, -1),
          end: Alignment(x * 2 - 1 + 0.5, 1),
          colors: const [Color(0x00FFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)],
          stops: const [0.35, 0.5, 0.65],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlossPainter old) => false;
}
