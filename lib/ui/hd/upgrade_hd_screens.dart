// Upgrade to HD: a short "Checking your requirements" loader, then
// Eligibility → HD Offer → Review & Confirm → Success. A numbered step bar
// sits at the top of the three middle screens. The Family HD Pack replaces
// the SD versions of its channels, so nothing is lost.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../home/connection_card.dart' show fmtDate;
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

const _packName = 'Family HD Pack';
const _packPrice = 399.0;

/// How much more the HD pack costs than the current pack, a month.
const _vsCurrent = 50.0;

const _logoBase = 'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/channels/';
const _logoSlugs = {'National Geographic': 'national-geographic-channel', 'Sony': 'sony-entertainment-television'};

/// The public dishtv.in logo for a channel, by the same slug convention the
/// rest of the app uses.
String _logo(String name) {
  final n = name.replaceAll(RegExp(r'\s+(HD|SD)$'), '').trim();
  final slug = _logoSlugs[n] ?? n.replaceAll('&', 'and').replaceAll(RegExp(r'[+./]'), '').replaceAll(RegExp(r'\s+'), '-').toLowerCase();
  return '$_logoBase$slug.webp';
}

const _hdChannels = [
  'Colors HD', 'Discovery HD', 'HBO HD', 'National Geographic HD', 'Sony HD', 'Sony Max HD', 'Sony SAB HD', //
  'Star Plus HD', 'Zee TV HD', 'Star Gold HD', 'Star Sports 1 HD', 'Sony Ten 1 HD', 'Zee Cinema HD', 'Colors Cineplex HD',
];
const _sdReplaced = ['Colors', 'Sony', 'Star Plus', 'Zee TV'];

/// The three things checked, in order.
const _equipment = [
  (Icons.router_outlined, 'Set-top box'),
  (Icons.satellite_alt_outlined, 'Dish antenna & LNB'),
  (Icons.settings_remote_outlined, 'Remote control'),
];

Route<T> _route<T>(Widget w) => MaterialPageRoute<T>(builder: (_) => w);

bool _still(BuildContext c) => MediaQuery.of(c).disableAnimations;

// ---------------------------------------------------------------------------
// Shared pieces

/// Eligibility · HD Offer · Review & Confirm: labels over numbered circles
/// joined by a line. Done steps are orange with a check, the current one is
/// orange with its number, later ones are quiet.
class _StepBar extends StatelessWidget {
  const _StepBar(this.current);

  /// 0, 1 or 2.
  final int current;

  static const _labels = ['Eligibility', 'HD Offer', 'Review & Confirm'];

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final done = i < current, on = i == current;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: on && !_still(context) ? 0.6 : 1, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: done || on ? G.brand : null, color: done || on ? null : C.surface, shape: BoxShape.circle),
          child: done
              ? const Icon(Icons.check_sharp, color: Colors.white, size: 17)
              : Text('${i + 1}', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : C.muted)),
        ),
      );
    }

    Widget line(int i) => Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(gradient: i < current ? G.brand : null, color: i < current ? null : C.lineStrong),
          ),
        );

    return Semantics(
      label: 'Step ${current + 1} of 3, ${_labels[current]}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.xl),
          child: Column(children: [
            Row(children: [
              for (final (i, l) in _labels.indexed)
                Expanded(
                  child: BrandShade(
                    on: i == current,
                    child: Text(l,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: T.label.copyWith(fontSize: 12.5, fontWeight: i == current ? FontWeight.w700 : FontWeight.w500, color: i < current ? C.ink : C.muted)),
                  ),
                ),
            ]),
            const SizedBox(height: S.sm),
            // Circles centred under their labels: half a column of padding at each end.
            LayoutBuilder(builder: (context, box) {
              final edge = box.maxWidth / 6 - 15;
              return Row(children: [SizedBox(width: edge), dot(0), line(0), dot(1), line(1), dot(2), SizedBox(width: edge)]);
            }),
          ]),
        ),
      ),
    );
  }
}

/// A count in a small quiet square, e.g. the 14 beside "HD channels added".
class _Count extends StatelessWidget {
  const _Count(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        color: C.surface,
        child: Text('$n', style: T.label.copyWith(fontSize: 12, color: C.inkSoft)),
      );
}

/// A channel's logo on a white square, with a fallback of its initials.
class _LogoTile extends StatelessWidget {
  const _LogoTile(this.name);
  final String name;
  static const size = 52.0;

  @override
  Widget build(BuildContext context) {
    final initials = name.replaceAll(RegExp(r'\s+(HD|SD)$'), '').split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join();
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(size * 0.12),
      child: Image.network(
        _logo(name),
        fit: BoxFit.contain,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => Center(child: Text(initials, style: T.label.copyWith(fontSize: size * 0.28, color: C.muted))),
      ),
    );
  }
}

/// A 4-column grid of channel logos. With [limit], the last cell becomes a
/// dashed "+N View more" tile that opens the full list.
class _ChannelGrid extends StatefulWidget {
  const _ChannelGrid({required this.names, this.limit, this.faded = false});

  final List<String> names;
  final int? limit;
  final bool faded;

  @override
  State<_ChannelGrid> createState() => _ChannelGridState();
}

class _ChannelGridState extends State<_ChannelGrid> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final cut = widget.limit != null && !_all && widget.names.length > widget.limit!;
    final shown = cut ? widget.names.take(widget.limit! - 1).toList() : widget.names;
    final cells = <Widget>[
      for (final (i, n) in shown.indexed) Reveal(order: i % 8, child: _cell(n)),
      if (cut) _more(widget.names.length - shown.length),
    ];
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 3 * S.sm) / 4;
      return Wrap(spacing: S.sm, runSpacing: S.lg, children: [for (final c in cells) SizedBox(width: w, child: c)]);
    });
  }

  Widget _cell(String name) {
    final quality = name.endsWith(' HD') ? 'HD' : 'SD';
    final plain = name.replaceAll(RegExp(r'\s+HD$'), '');
    return Semantics(
      label: '$plain, $quality',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: widget.faded ? 0.35 : 1,
          child: Column(children: [
            const SizedBox(height: 2),
            _LogoTile(name),
            const SizedBox(height: 8),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
            Text(quality, style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _more(int n) => Semantics(
        button: true,
        label: 'View $n more channels',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _all = true),
            child: Column(children: [
              const SizedBox(height: 2),
              CustomPaint(
                painter: const _Dashed(),
                child: SizedBox(width: 52, height: 52, child: Center(child: Text('+$n', style: T.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600)))),
              ),
              const SizedBox(height: 8),
              BrandShade(child: Text('View more', style: T.label.copyWith(fontSize: 12.5, color: C.brand))),
            ]),
          ),
        ),
      );
}

/// A dashed square outline.
class _Dashed extends CustomPainter {
  const _Dashed();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.lineStrong
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    void dash(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 7) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 4, len), p);
      }
    }

    final r = Offset.zero & size;
    dash(r.topLeft, r.topRight);
    dash(r.topRight, r.bottomRight);
    dash(r.bottomRight, r.bottomLeft);
    dash(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_Dashed old) => false;
}

/// A section title with a count and a fold arrow; folds its content.
class _Fold extends StatefulWidget {
  const _Fold({required this.title, required this.count, required this.child});

  final String title;
  final int count;
  final Widget child;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  bool _open = true;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          expanded: _open,
          label: '${widget.title}, ${widget.count}',
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: S.sm),
              child: Row(children: [
                Text(widget.title, style: T.section.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: S.sm),
                _Count(widget.count),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_up_sharp, color: C.inkSoft, size: 22),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? Padding(padding: const EdgeInsets.only(top: S.md), child: widget.child) : const SizedBox(width: double.infinity),
        ),
      ]);
}

/// "Bedroom · VC 0102 7734 5582 ▾": opens the TV picker when there's more
/// than one TV.
class _TvLine extends StatelessWidget {
  const _TvLine();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    if (c == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
        child: InkWell(
          onTap: app.connections.length > 1
              ? () async {
                  final vc = await showSwitchTvSheet(context);
                  if (vc != null) app.selectVc(vc);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c.label, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
              Text('  ·  VC ', style: T.caption.copyWith(color: C.muted)),
              Text(c.vcPretty, style: T.label.copyWith(fontSize: 13.5, color: C.ink, fontWeight: FontWeight.w700)),
              if (app.connections.length > 1) ...[const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20)],
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 0 · Checking your requirements (loader)

/// The way into Upgrade to HD: a short check of the TV's equipment with a
/// scanning animation, then on to Eligibility on its own.
class HdCheckScreen extends StatefulWidget {
  const HdCheckScreen({super.key});

  @override
  State<HdCheckScreen> createState() => _HdCheckScreenState();
}

class _HdCheckScreenState extends State<HdCheckScreen> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  int _checked = 0;
  final _timers = <Timer>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timers.isNotEmpty || _checked > 0) return;
    if (_still(context)) {
      // Reduce Motion: no animation, just a brief pause before moving on.
      _checked = _equipment.length;
      _progress.value = 1;
      _timers.add(Timer(const Duration(milliseconds: 600), _next));
      return;
    }
    _spin.repeat();
    _pulse.repeat();
    _progress.forward();
    for (var i = 0; i < _equipment.length; i++) {
      _timers.add(Timer(Duration(milliseconds: 800 + i * 750), () {
        if (!mounted) return;
        HapticFeedback.selectionClick();
        setState(() => _checked = i + 1);
      }));
    }
    _timers.add(Timer(const Duration(milliseconds: 3300), _next));
  }

  void _next() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => const HdEligibilityScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _spin.dispose();
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppStore>().connection;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Header(title: 'Upgrade to HD'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, S.xl),
              children: [
                Center(child: SizedBox(width: 200, height: 200, child: _scanner())),
                const SizedBox(height: S.xl),
                Text('Checking your requirements', textAlign: TextAlign.center, style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: S.sm),
                Text(
                  c == null ? 'Making sure your equipment supports HD.' : 'Making sure ${c.label}\'s equipment supports HD.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(color: C.muted),
                ),
                const SizedBox(height: S.xxl),
                for (final (i, e) in _equipment.indexed) _checkRow(i, e.$1, e.$2),
                const SizedBox(height: S.xl),
                // Overall progress, in the card gradient.
                Container(
                  height: 3,
                  color: C.surface,
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) => FractionallySizedBox(
                      widthFactor: Curves.easeInOut.transform(_progress.value),
                      child: Container(decoration: const BoxDecoration(gradient: G.brand)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// Pulsing rings and a rotating gradient arc around the HD mark.
  Widget _scanner() => AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (_, __) => CustomPaint(
          painter: _ScanPainter(spin: _spin.value, pulse: _pulse.value),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
              child: _checked >= _equipment.length
                  ? BrandShade(key: ValueKey('done'), child: Icon(Icons.check_circle_outline_sharp, size: 56, color: C.brand))
                  : BrandShade(key: ValueKey('hd'), child: Icon(Icons.hd_outlined, size: 56, color: C.brand)),
            ),
          ),
        ),
      );

  Widget _checkRow(int i, IconData icon, String label) {
    final done = i < _checked;
    final active = i == _checked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: done || active ? 1 : 0.4,
        child: Row(children: [
          Icon(icon, size: 22, color: C.ink),
          const SizedBox(width: S.md),
          Expanded(child: Text(label, style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500))),
          SizedBox(
            width: 24,
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
              child: done
                  ? BrandShade(key: ValueKey('ok'), child: Icon(Icons.check_circle_sharp, size: 22, color: C.brand))
                  : active
                      ? Padding(key: ValueKey('wait'), padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: C.inkSoft))
                      : const SizedBox(key: ValueKey('idle')),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Two rings that grow and fade outward, and an orange arc that turns.
class _ScanPainter extends CustomPainter {
  const _ScanPainter({required this.spin, required this.pulse});

  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    // Rings: two, half a cycle apart.
    for (final phase in [pulse, (pulse + 0.5) % 1]) {
      final r = base * (0.45 + 0.55 * phase);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFE5622E).withValues(alpha: 0.5 * (1 - phase)),
      );
    }
    // A quiet track and the turning arc.
    final track = Rect.fromCircle(center: c, radius: base * 0.5);
    canvas.drawCircle(c, base * 0.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = C.surface);
    canvas.drawArc(
      track,
      spin * 2 * math.pi - math.pi / 2,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: const [Color(0x00E5622E), Color(0xFFFF8A5B), Color(0xFFC24A22)],
          stops: const [0, 0.25, 0.35],
          transform: GradientRotation(spin * 2 * math.pi - math.pi / 2),
        ).createShader(track),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.spin != spin || old.pulse != pulse;
}

// ---------------------------------------------------------------------------
// 1 · Eligibility

class HdEligibilityScreen extends StatelessWidget {
  const HdEligibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Upgrade to HD'),
          const _TvLine(),
          const _StepBar(0),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xl),
              children: [
                // The one strong block: the card gradient.
                Reveal(
                  child: Container(
                    decoration: const BoxDecoration(gradient: G.brand),
                    padding: const EdgeInsets.all(S.lg + 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.hd_outlined, color: Colors.white, size: 34)),
                      const SizedBox(width: S.md + 2),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your connection is HD-ready', style: T.title.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Your equipment supports HD. Upgrade your pack to watch ${_hdChannels.length} channels in crystal-clear HD.',
                              style: T.body.copyWith(color: const Color(0xE6FFFFFF), fontSize: 13.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: S.xxl),
                Text('YOUR EQUIPMENT', style: T.overline.copyWith(fontSize: 11.5)),
                const SizedBox(height: S.xs),
                if (c != null)
                  FutureBuilder<Warranty>(
                    future: app.warrantyOf(c.vc),
                    builder: (context, snap) {
                      final w = snap.data;
                      if (w == null) return const Padding(padding: EdgeInsets.only(top: S.md), child: Skeleton(height: 180));
                      final on = '${fmtDate(w.installedOn)} ${w.installedOn.year}';
                      final rows = [
                        ('Set-top box · ${w.items.first.model ?? 'HD'}', 'Supports HD · installed $on', 'HD ready'),
                        ('Dish antenna & LNB', 'Installed $on', 'Compatible'),
                        ('Remote control', 'Installed $on', 'Compatible'),
                      ];
                      return Column(children: [
                        for (final (i, r) in rows.indexed) ...[
                          if (i > 0) Divider(height: 1, color: C.line),
                          Reveal(
                            order: i + 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: S.lg),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(r.$1, style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 3),
                                    Text(r.$2, style: T.caption.copyWith(fontSize: 13, color: C.muted)),
                                  ]),
                                ),
                                const SizedBox(width: S.sm),
                                _OkPill(r.$3),
                              ]),
                            ),
                          ),
                        ],
                      ]);
                    },
                  ),
              ],
            ),
          ),
          BottomBar(child: PrimaryButton(label: 'See HD Offer', onTap: c == null ? null : () => Navigator.of(context).push(_route(const HdOfferScreen())))),
        ]),
      ),
    );
  }
}

/// "✓ HD ready" / "✓ Compatible": green text on a faint green pill.
class _OkPill extends StatelessWidget {
  const _OkPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: const Color(0x2463BF8E),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_sharp, size: 15, color: C.success),
          const SizedBox(width: 5),
          Text(text, style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.success)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// 2 · HD Offer

class HdOfferScreen extends StatelessWidget {
  const HdOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'HD Offer'),
          const _StepBar(1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xl),
              children: [
                // The offer, framed by a thin line in the card gradient.
                Reveal(
                  child: Container(
                    decoration: BoxDecoration(gradient: G.brandInk),
                    padding: const EdgeInsets.all(1.5),
                    child: Container(
                      color: C.surface,
                      padding: const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, S.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_packName, style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('${_hdChannels.length} HD channels · 30 days', style: T.caption.copyWith(fontSize: 13, color: C.muted)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            _CountUp(_packPrice, style: T.price.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            BrandShade(child: Text('+ ${rupees(_vsCurrent)}/mo vs current', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.brand))),
                          ]),
                        ]),
                        const SizedBox(height: S.md),
                        Divider(height: 1, color: C.line),
                        const SizedBox(height: S.md),
                        Text('Keep your TV experience in stunning HD premium clarity.', style: T.body.copyWith(fontSize: 14, color: C.inkSoft)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: S.xl),
                _Fold(title: 'HD channels added', count: _hdChannels.length, child: const _ChannelGrid(names: _hdChannels, limit: 8)),
                const SizedBox(height: S.lg),
                Divider(height: 1, color: C.line),
                const SizedBox(height: S.lg),
                _Fold(title: 'SD versions replaced', count: _sdReplaced.length, child: _ChannelGrid(names: [for (final n in _sdReplaced) '$n SD'], faded: true)),
                const SizedBox(height: S.lg),
                Divider(height: 1, color: C.line),
                const SizedBox(height: S.lg),
                Text("The SD versions are replaced by their HD channels, so you don't lose any content.", style: T.caption.copyWith(fontSize: 13, color: C.muted)),
              ],
            ),
          ),
          BottomBar(child: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_sharp, onTap: () => Navigator.of(context).push(_route(const HdReviewScreen())))),
        ]),
      ),
    );
  }
}

/// Counts a rupee amount up from zero when it first shows.
class _CountUp extends StatelessWidget {
  const _CountUp(this.value, {required this.style, this.decimals = false});
  final double value;
  final TextStyle style;
  final bool decimals;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: _still(context) ? value : 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(decimals ? '₹${v.toStringAsFixed(2)}' : rupees(v.roundToDouble()), style: style),
      );
}

// ---------------------------------------------------------------------------
// 3 · Review & Confirm

class HdReviewScreen extends StatefulWidget {
  const HdReviewScreen({super.key});

  @override
  State<HdReviewScreen> createState() => _HdReviewScreenState();
}

class _HdReviewScreenState extends State<HdReviewScreen> {
  bool _busy = false;
  bool _open = true;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushAndRemoveUntil(_route(const HdSuccessScreen()), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppStore>().connection;
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: T.body.copyWith(fontSize: 14.5, color: C.inkSoft))),
            Text(b, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ]),
        );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Header(title: 'Review & Confirm'),
            const _StepBar(2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg),
                children: [
                  Semantics(
                    button: true,
                    expanded: _open,
                    label: '$_packName, ${rupees(_packPrice)} a month',
                    child: InkWell(
                      onTap: () => setState(() => _open = !_open),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(_packName, style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              AnimatedRotation(
                                turns: _open ? 0 : 0.5,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.keyboard_arrow_up_sharp, color: C.inkSoft, size: 22),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(['${_hdChannels.length} HD channels', '30 days', if (c != null) c.label].join(' · '), style: T.caption.copyWith(fontSize: 13, color: C.muted)),
                          ]),
                        ),
                        Text('${rupees(_packPrice)}/mo', style: T.price.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _open
                        ? const Padding(padding: EdgeInsets.only(top: S.lg), child: _ChannelGrid(names: _hdChannels, limit: 8))
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            // The monthly cost, pinned above the button.
            Container(
              padding: EdgeInsets.fromLTRB(S.page, S.xl, S.page, S.lg + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('MONTHLY COST', style: T.overline.copyWith(fontSize: 11.5)),
                const SizedBox(height: S.sm),
                row(_packName, '₹${_packPrice.toStringAsFixed(2)}'),
                row('vs current pack', '+ ₹${_vsCurrent.toStringAsFixed(2)}'),
                Padding(padding: EdgeInsets.symmetric(vertical: S.md), child: Divider(height: 1, color: C.line)),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('Total', style: T.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('per month', style: T.caption.copyWith(fontSize: 13, color: C.muted)),
                  const Spacer(),
                  _CountUp(_packPrice, decimals: true, style: T.price.copyWith(fontSize: 26, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: S.lg),
                PrimaryButton(label: 'Confirm & Apply', busy: _busy, onTap: _confirm),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success

class HdSuccessScreen extends StatefulWidget {
  const HdSuccessScreen({super.key});

  @override
  State<HdSuccessScreen> createState() => _HdSuccessScreenState();
}

class _HdSuccessScreenState extends State<HdSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final String _id = 'TKT-${2200000 + DateTime.now().millisecondsSinceEpoch % 99999}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.4).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppStore>().connection;
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
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.45, curve: Curves.elasticOut)),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(color: C.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check_sharp, color: Colors.white, size: 46),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.25,
                      Column(children: [
                        Text('Pack updated successfully', textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text('Your HD channels will start within a few minutes.', textAlign: TextAlign.center, style: T.body),
                        const SizedBox(height: S.md),
                        Text('Order ID · $_id', style: T.label.copyWith(color: C.muted)),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    if (c != null)
                      _fade(
                        0.4,
                        Container(
                          decoration: const BoxDecoration(gradient: G.brand),
                          padding: const EdgeInsets.all(S.lg),
                          child: IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(child: _figure('Next recharge', fmtDate(c.switchOffDate))),
                              Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.lg), color: const Color(0x40FFFFFF)),
                              Expanded(child: _figure('Monthly pack', rupees(_packPrice))),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.5,
                      Container(
                        color: C.surface,
                        padding: const EdgeInsets.all(S.lg),
                        child: Row(children: [
                          Icon(Icons.hd_outlined, color: C.ink, size: 28),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_packName, style: T.item.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600)),
                              Text('Now active on ${c?.label ?? 'your TV'}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                            ]),
                          ),
                          const SizedBox(width: S.md),
                          Text('${rupees(_packPrice)}/mo', style: T.price.copyWith(fontSize: 16)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.6,
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Text('HD channels added', style: T.section.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(width: S.sm),
                          _Count(_hdChannels.length),
                        ]),
                        const SizedBox(height: S.lg),
                        const _ChannelGrid(names: _hdChannels, limit: 8),
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

  Widget _figure(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.price.copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))),
      ]);
}
