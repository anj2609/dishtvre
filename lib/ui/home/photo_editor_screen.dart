// Edit photo: frame a profile picture inside a circle. Pinch to zoom, drag
// to move, rotate in quarter turns, flip, pick an effect, or reset. "Use
// photo" returns the framed square (with its effect) as PNG bytes; Cancel
// returns nothing.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../widgets/widgets.dart';

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final _frame = GlobalKey();
  final _view = TransformationController();
  int _turns = 0;
  bool _flip = false;
  int _effect = 0;
  bool _saving = false;

  // Effects as colour matrices (null = the photo as it is).
  static const _lr = 0.2126, _lg = 0.7152, _lb = 0.0722;
  static List<double> _saturate(double s) => [
        _lr * (1 - s) + s, _lg * (1 - s), _lb * (1 - s), 0, 0, //
        _lr * (1 - s), _lg * (1 - s) + s, _lb * (1 - s), 0, 0,
        _lr * (1 - s), _lg * (1 - s), _lb * (1 - s) + s, 0, 0,
        0, 0, 0, 1, 0,
      ];
  static List<double> _mono(double contrast) {
    final t = (1 - contrast) * 128;
    return [
      _lr * contrast, _lg * contrast, _lb * contrast, 0, t, //
      _lr * contrast, _lg * contrast, _lb * contrast, 0, t,
      _lr * contrast, _lg * contrast, _lb * contrast, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  static final _effects = <(String, List<double>?)>[
    ('Original', null),
    ('Mono', _mono(1)),
    ('Noir', _mono(1.45)),
    ('Warm', [1.12, 0, 0, 0, 8, 0, 1.0, 0, 0, 2, 0, 0, 0.84, 0, -12, 0, 0, 0, 1, 0]),
    ('Cool', [0.88, 0, 0, 0, -8, 0, 1.0, 0, 0, 0, 0, 0, 1.16, 0, 14, 0, 0, 0, 1, 0]),
    ('Vivid', _saturate(1.55)),
    ('Fade', [0.8, 0, 0, 0, 34, 0, 0.8, 0, 0, 34, 0, 0, 0.8, 0, 34, 0, 0, 0, 1, 0]),
  ];

  /// The photo with the current flip and effect.
  Widget _styled(double side, int effect) {
    Widget img = Image.memory(widget.bytes, width: side, height: side, fit: BoxFit.cover, gaplessPlayback: true);
    if (_flip) img = Transform.flip(flipX: true, child: img);
    final m = _effects[effect].$2;
    return m == null ? img : ColorFiltered(colorFilter: ColorFilter.matrix(m), child: img);
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _rotate() => setState(() {
        _turns = (_turns + 3) % 4; // anticlockwise
        _view.value = Matrix4.identity();
      });

  void _reset() => setState(() {
        _turns = 0;
        _flip = false;
        _effect = 0;
        _view.value = Matrix4.identity();
      });

  // Render what's inside the frame to a 600 px square PNG.
  Future<void> _use() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final ro = _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 600 / ro.size.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (!mounted) return;
    nav.pop(data?.buffer.asUint8List());
  }

  /// One effect preview: the photo in that look, with its name.
  Widget _effectChip(int i) {
    final on = i == _effect;
    final name = _effects[i].$1;
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: '$name effect',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => setState(() => _effect = i),
          child: Column(children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? C.brand : Colors.transparent, width: 2)),
              child: ClipOval(child: _styled(52, i)),
            ),
            const SizedBox(height: 6),
            Text(name, textScaler: TextScaler.noScaling, style: T.label.copyWith(fontSize: 12, color: on ? C.brand : C.muted)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Edit photo', subtitle: 'Pinch to zoom, drag to move'),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final side = math.max(160.0, math.min(420.0, math.min(box.maxWidth - S.page * 2, box.maxHeight - 200)));
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                      width: side,
                      height: side,
                      child: Stack(children: [
                        // What gets saved: the photo, framed.
                        RepaintBoundary(
                          key: _frame,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _view,
                              minScale: 1,
                              maxScale: 6,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: RotatedBox(quarterTurns: _turns, child: _styled(side, _effect)),
                              ),
                            ),
                          ),
                        ),
                        // The circle it will be shown in.
                        IgnorePointer(child: CustomPaint(size: Size.square(side), painter: _CircleMask())),
                      ]),
                    ),
                    const SizedBox(height: S.lg),
                    Wrap(spacing: S.sm, runSpacing: S.sm, alignment: WrapAlignment.center, children: [
                      _Tool(icon: Icons.rotate_90_degrees_ccw_outlined, label: 'Rotate', onTap: _rotate),
                      _Tool(icon: Icons.flip_outlined, label: 'Flip', active: _flip, onTap: () => setState(() => _flip = !_flip)),
                      _Tool(icon: Icons.restart_alt_rounded, label: 'Reset', onTap: _reset),
                    ]),
                    const SizedBox(height: S.lg),
                    // Effects: small previews of this photo in each look.
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: S.page),
                        itemCount: _effects.length,
                        separatorBuilder: (_, __) => const SizedBox(width: S.md),
                        itemBuilder: (_, i) => _effectChip(i),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
          BottomBar(
            child: Row(children: [
              Expanded(child: SecondaryButton(label: 'Cancel', onTap: () => Navigator.of(context).pop())),
              const SizedBox(width: S.md),
              Expanded(child: PrimaryButton(label: 'Use photo', busy: _saving, onTap: _use)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Darkens everything outside the circle and draws its edge.
class _CircleMask extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = const Color(0xB3000000));
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CircleMask old) => false;
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? C.brand : Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: active ? C.brand : C.lineStrong)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 19, color: active ? Colors.white : C.ink),
              const SizedBox(width: 6),
              Text(label, style: T.label.copyWith(color: active ? Colors.white : C.ink)),
            ]),
          ),
        ),
      );
}
