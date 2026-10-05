// Edit photo: frame a profile picture inside a circle. Pinch to zoom, drag
// to move, rotate in quarter turns, or reset. "Use photo" returns the framed
// square as PNG bytes; Cancel returns nothing.

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
  bool _saving = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Edit photo', subtitle: 'Pinch to zoom, drag to move'),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final side = math.max(160.0, math.min(420.0, math.min(box.maxWidth - S.page * 2, box.maxHeight - 96)));
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
                                child: RotatedBox(
                                  quarterTurns: _turns,
                                  child: Image.memory(widget.bytes, width: side, height: side, fit: BoxFit.cover, gaplessPlayback: true),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The circle it will be shown in.
                        IgnorePointer(child: CustomPaint(size: Size.square(side), painter: _CircleMask())),
                      ]),
                    ),
                    const SizedBox(height: S.lg),
                    Wrap(spacing: S.md, runSpacing: S.sm, alignment: WrapAlignment.center, children: [
                      _Tool(icon: Icons.rotate_90_degrees_ccw_outlined, label: 'Rotate', onTap: _rotate),
                      _Tool(icon: Icons.restart_alt_rounded, label: 'Reset', onTap: _reset),
                    ]),
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
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        shape: const RoundedRectangleBorder(side: BorderSide(color: C.lineStrong)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 19, color: C.ink),
              const SizedBox(width: 6),
              Text(label, style: T.label),
            ]),
          ),
        ),
      );
}
