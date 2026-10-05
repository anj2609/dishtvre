// Shared building blocks. Screens compose these; they never style raw
// Material widgets themselves.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Screen header: round back button, title, optional subtitle and trailing.
class Header extends StatelessWidget {
  const Header({super.key, required this.title, this.subtitle, this.trailing, this.onBack, this.plainBack = true, this.inline = false});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  /// Back arrow without a background or border.
  final bool plainBack;

  /// Keep the trailing action on the title's line even with large text.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final titles = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: T.title)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!, style: T.caption),
      ],
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.md),
      child: LayoutBuilder(builder: (context, box) {
        final back = RoundIconButton(
          icon: Icons.arrow_back_sharp,
          label: 'Back',
          filled: !plainBack,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
        );
        // With large text on a narrow screen, keep the title readable by
        // moving the trailing action onto its own line.
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final stack = !inline && trailing != null && (box.maxWidth < 360 || scale > 1.3);
        if (stack) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [back, const SizedBox(width: S.md), Expanded(child: titles)]),
            const SizedBox(height: S.sm),
            Padding(padding: const EdgeInsets.only(left: 56), child: trailing!),
          ]);
        }
        return Row(children: [
          back,
          const SizedBox(width: S.md),
          Expanded(child: titles),
          if (trailing != null) ...[const SizedBox(width: S.sm), inline ? Flexible(child: trailing!) : trailing!],
        ]);
      }),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, this.onTap, this.filled = true, this.badge = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        decoration: filled
            ? const BoxDecoration(
                shape: BoxShape.circle,
                color: C.cardTop,
                border: Border.fromBorderSide(BorderSide(color: C.cardEdge)),
                boxShadow: D.lift,
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, size: 21, color: C.ink),
                if (badge)
                  Positioned(
                    top: 11,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: C.brand, shape: BoxShape.circle, border: Border.all(color: C.surface, width: 1.5)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one main action on a screen: a raised key that presses down.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.busy = false, this.icon, this.subtitle});

  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null && !widget.busy;
    const radius = R.md + 2;
    return Semantics(
      container: true,
      button: true,
      enabled: on,
      child: Listener(
        onPointerDown: on ? (_) => _set(true) : null,
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          constraints: const BoxConstraints(minHeight: 54),
          decoration: on || widget.busy ? D.accentButton(radius: radius, pressed: _down) : BoxDecoration(border: Border.all(color: C.lineStrong)),
          foregroundDecoration: on ? D.sheen(radius) : null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: on ? widget.onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.sm),
                child: Center(
                  child: widget.busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(
                              child:
                                  Text(widget.label, textAlign: TextAlign.center, style: T.item.copyWith(fontSize: 15.5, color: on ? Colors.white : C.faint)),
                            ),
                            if (widget.icon != null) ...[const SizedBox(width: 8), Icon(widget.icon, size: 19, color: on ? Colors.white : C.faint)],
                          ]),
                          if (widget.subtitle != null)
                            Text(widget.subtitle!,
                                textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 11.5, color: on ? const Color(0xE6FFFFFF) : C.faint)),
                        ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Outline only, no fill.
      decoration: BoxDecoration(border: Border.all(color: C.lineStrong)),
      position: DecorationPosition.background,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.lg),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 19, color: C.ink), const SizedBox(width: 8)],
                Flexible(child: Text(label, textAlign: TextAlign.center, style: T.item.copyWith(fontSize: 15))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card lifted off the page: lit top edge, soft shadow beneath.
/// Pass [color] for a flat tinted note instead.
class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(S.lg),
      this.onTap,
      this.color = C.surface,
      this.borderColor = C.line,
      this.radius = R.lg});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final raised = color == C.surface;
    final inner = Material(
      type: MaterialType.transparency,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return Container(
      decoration: raised
          ? D.card(radius: radius, edge: borderColor == C.line ? null : borderColor)
          : BoxDecoration(color: color, borderRadius: BorderRadius.zero, border: Border.all(color: borderColor)),
      foregroundDecoration: raised ? D.sheen(radius) : null,
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(S.page, S.xxl, S.page, S.md)});

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(text, style: T.section))),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(action!, style: T.label.copyWith(color: C.brandDeep)),
            ),
          ),
      ]),
    );
  }
}

/// Small coloured label.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.fg = C.inkSoft, this.bg = C.sunken, this.icon});

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: T.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg))),
      ]),
    );
  }
}

/// Selectable chip: outline when off, ink-filled when on.
class Pick extends StatelessWidget {
  const Pick({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          // Outline when off; solid orange with a small radius when on.
          decoration: BoxDecoration(
            color: selected ? C.brand : null,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? C.brand : C.lineStrong),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: selected
                  ? const Icon(Icons.check_sharp, key: ValueKey('on'), size: 16, color: Colors.white)
                  : (icon != null ? Icon(icon, key: const ValueKey('icon'), size: 15, color: C.muted) : const SizedBox(key: ValueKey('none'))),
            ),
            if (selected || icon != null) const SizedBox(width: 6),
            Flexible(child: Text(label, style: T.label.copyWith(fontSize: 13, color: selected ? Colors.white : C.ink))),
          ]),
        ),
      ),
    );
  }
}

/// Segmented switch with one white pill that glides between options and a
/// label colour that follows it.
class Segmented<V> extends StatefulWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.height = 40});

  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;
  final double height;

  @override
  State<Segmented<V>> createState() => _SegmentedState<V>();
}

class _SegmentedState<V> extends State<Segmented<V>> with SingleTickerProviderStateMixin {
  late int _i = _index(widget.value);
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: _i.toDouble());

  int _index(V v) => widget.options.indexWhere((o) => o.$1 == v).clamp(0, widget.options.length - 1);

  @override
  void didUpdateWidget(Segmented<V> old) {
    super.didUpdateWidget(old);
    final i = _index(widget.value);
    if (i != _i) _go(i);
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _go(int i) {
    _i = i;
    _pos.animateTo(i.toDouble(), duration: const Duration(milliseconds: 320), curve: Curves.easeInOutCubic);
  }

  void _tap(int i) {
    if (i == _i) return;
    HapticFeedback.selectionClick();
    _go(i);
    // Report after the glide so a heavy rebuild doesn't land mid-animation.
    final v = widget.options[i].$1;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _i == i) widget.onChanged(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.options.length;
    final scaler = MediaQuery.textScalerOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(border: Border.all(color: C.lineStrong)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / n;
        // Labels wrap only between words (the font shrinks a little if one
        // word is too wide), and the bar grows to fit the tallest label.
        final avail = math.max(1.0, w - 8);
        final base = T.label.copyWith(fontSize: 13);
        var widest = 0.0;
        for (final o in widget.options) {
          for (final word in o.$2.split(' ')) {
            final tp = TextPainter(text: TextSpan(text: word, style: base), textScaler: scaler, textDirection: TextDirection.ltr, maxLines: 1)..layout();
            widest = math.max(widest, tp.width);
            tp.dispose();
          }
        }
        final style = widest > avail ? base.copyWith(fontSize: 13 * avail / widest * 0.97) : base;
        var tallest = 0.0;
        for (final o in widget.options) {
          final tp = TextPainter(text: TextSpan(text: o.$2, style: style), textScaler: scaler, textDirection: TextDirection.ltr, textAlign: TextAlign.center)
            ..layout(maxWidth: avail);
          tallest = math.max(tallest, tp.height);
          tp.dispose();
        }
        final h = math.max(widget.height + (scaler.scale(13) - 13) * 1.6, tallest + 14);
        return SizedBox(
          height: h,
          child: AnimatedBuilder(
            animation: _pos,
            builder: (_, __) => Stack(children: [
              Positioned(
                left: _pos.value * w,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  // Selected option: solid orange, square corners.
                  decoration: const BoxDecoration(color: C.brand),
                ),
              ),
              Row(children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      container: true,
                      button: true,
                      selected: i == _i,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tap(i),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              widget.options[i].$2,
                              textAlign: TextAlign.center,
                              style: style.copyWith(
                                color: Color.lerp(C.muted, Colors.white, (1 - (_pos.value - i).abs()).clamp(0.0, 1.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

/// Sticky bottom bar for a screen's main action.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(S.page, S.md, S.page, S.md + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.cardEdge)),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// Search box.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.hint, required this.controller, required this.onChanged});

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(border: Border.all(color: C.lineStrong)),
      child: Row(children: [
        const Icon(Icons.search_sharp, size: 20, color: C.muted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: T.body.copyWith(color: C.ink),
            decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: hint, hintStyle: T.body.copyWith(color: C.faint)),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox(width: 8)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_sharp, size: 18, color: C.muted),
                ),
        ),
      ]),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title, this.body, this.icon = Icons.search_off_sharp, this.action, this.onAction});

  final String title;
  final String? body;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.xxl, vertical: 40),
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: C.sunken, shape: BoxShape.circle),
          child: Icon(icon, color: C.muted),
        ),
        const SizedBox(height: S.md),
        Text(title, textAlign: TextAlign.center, style: T.item),
        if (body != null) ...[const SizedBox(height: 4), Text(body!, textAlign: TextAlign.center, style: T.caption)],
        if (action != null) ...[
          const SizedBox(height: S.lg),
          TextButton(onPressed: onAction, child: Text(action!, style: T.label.copyWith(color: C.brandDeep))),
        ],
      ]),
    );
  }
}

/// Grey placeholder block while something loads.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 88});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        margin: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
        decoration: BoxDecoration(color: C.sunken, borderRadius: BorderRadius.zero),
      );
}

/// Opens a bottom sheet in the app's style.
Future<V?> showSheet<V>(BuildContext context, {required String title, String? subtitle, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<V>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA6000000),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
      child: Container(
        decoration: const BoxDecoration(
          color: C.bg,
          // Rounded top corners: the one rounded surface, so sheets read as sheets.
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.fromBorderSide(BorderSide(color: C.lineStrong)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: C.lineStrong, borderRadius: BorderRadius.zero),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.page, S.md, S.md, S.sm),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: T.title.copyWith(fontSize: 19)),
                  if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: T.caption)],
                ]),
              ),
              RoundIconButton(icon: Icons.close_sharp, label: 'Close', filled: false, onTap: () => Navigator.of(ctx).pop()),
            ]),
          ),
          Flexible(child: builder(ctx)),
        ]),
      ),
    ),
  );
}

/// A channel's logo in a white circle. Falls back to the channel's initials
/// while the logo loads or if there isn't one.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.name, this.url, this.size = 40, this.ring = _ring});

  /// An orange frame around every logo.
  static const _ring = C.brand;

  final String name;
  final String? url;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .replaceAll(RegExp(r'\s+HD$'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp('[A-Za-z0-9&]').hasMatch(w[0]))
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Center(
      child: Text(initials, textScaler: TextScaler.noScaling, style: T.caption.copyWith(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: C.muted)),
    );
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(
          child: url == null
              ? fallback
              : Padding(
                  padding: EdgeInsets.all(size * 0.12),
                  child: Image.network(
                    url!,
                    fit: BoxFit.contain,
                    cacheWidth: px,
                    excludeFromSemantics: true,
                    frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : fallback,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

/// An OTT app's logo as a rounded app icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.name, this.url, this.size = 32});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: C.raised,
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '' : name[0].toUpperCase(), textScaler: TextScaler.noScaling, style: T.label.copyWith(fontSize: size * 0.4)),
    );
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: C.cardEdge),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  excludeFromSemantics: true,
                  frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : fallback,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}

/// [base], shrunk just enough that the widest single word in [labels] fits
/// in [width]. Text then wraps only between words, never inside one.
TextStyle wordSafe(BuildContext context, Iterable<String> labels, TextStyle base, double width) {
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final l in labels) {
    for (final word in l.split(RegExp(r'\s+'))) {
      final tp = TextPainter(text: TextSpan(text: word, style: base), textScaler: scaler, textDirection: TextDirection.ltr, maxLines: 1)..layout();
      widest = math.max(widest, tp.width);
      tp.dispose();
    }
  }
  return width > 0 && widest > width ? base.copyWith(fontSize: base.fontSize! * width / widest * 0.97) : base;
}

/// The account holder's photo in a circle, or their initials on orange.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.photo, this.size = 40});

  final String initials;
  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: C.brand, shape: BoxShape.circle),
        child: photo != null
            ? Image.memory(photo!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true)
            : Text(initials,
                textScaler: TextScaler.noScaling, style: T.label.copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}
