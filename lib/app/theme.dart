// Design tokens for DishTV Next — "Midnight".
//
// A sleek dark stage like a streaming app: near-black ground, solid
// charcoal cards with crisp edges and sharp corners, soft white type, and
// solid colour where colour means something (coral for the main action,
// one solid colour per feature). No gradients or glows. Every screen reads
// colours, type, spacing and radii from here.

import 'package:flutter/material.dart';

abstract final class C {
  // Ground and surfaces, darkest to lightest.
  static const bg = Color(0xFF08080C);
  static const sunken = Color(0xFF111117);
  static const surface = Color(0xFF18181F);
  static const raised = Color(0xFF24242F);
  static const line = Color(0xFF26262F);
  static const lineStrong = Color(0xFF383845);

  // Cards: lit from above (lighter top edge, darker base).
  // Cards: one solid shade, clearly lighter than the page.
  static const cardTop = Color(0xFF1E1E29);
  static const cardBottom = Color(0xFF1E1E29);
  static const cardEdge = Color(0xFF34343F);

  // One solid colour per feature, so each is recognisable at a glance.
  static const explore = Color(0xFFE85A2C);
  static const ai = Color(0xFF6656E0);
  static const addOns = Color(0xFF0E9488);

  // Text.
  static const ink = Color(0xFFF4F4F8);
  static const inkSoft = Color(0xFFC9C9D4);
  static const muted = Color(0xFF8E8EA2);
  static const faint = Color(0xFF5E5E71);

  /// Text on a light [ink] fill.
  static const onInk = Color(0xFF0B0B11);

  // Accent.
  static const brand = Color(0xFFFF6A3D);
  static const brandDark = Color(0xFFC4441F);
  static const brandDeep = Color(0xFFFF9B78);
  static const brandSoft = Color(0x2EFF6A3D);
  static const brandTint = Color(0x17FF6A3D);

  // Status.
  // Status, kept muted so nothing glares on the dark ground.
  static const success = Color(0xFF63BF8E);
  static const successSoft = Color(0x1F63BF8E);
  static const warning = Color(0xFFE2B45A);
  static const warningSoft = Color(0x1FE2B45A);
  static const danger = Color(0xFFF07C88);
  static const dangerSoft = Color(0x1FF07C88);
  static const info = Color(0xFF7FA8F0);
  static const infoSoft = Color(0x1F7FA8F0);

  // Connection states.
  static const vacation = Color(0xFF7FA8F0);
  static const vacationSoft = Color(0x1F7FA8F0);
  static const off = Color(0xFF9696A8);
  static const offSoft = Color(0x269696A8);

  // Kept for the few places that sit on a lit stage.
  static const night = bg;
  static const nightRaised = surface;
  static const onNight = ink;
  static const onNightMuted = muted;
  static const glass = Color(0x12FFFFFF);
  static const glassLine = Color(0x1FFFFFFF);
  static const magenta = Color(0xFFFF4D7E);
  static const violet = Color(0xFF8B6CFF);
  static const teal = Color(0xFF2CC5B5);
  static const cobalt = Color(0xFF4F7DFF);

  // Genre accents (text, background).
  static const genres = <String, (Color, Color)>{
    'Entertainment': (Color(0xFFFF9B78), Color(0x26FF6A3D)),
    'Movies': (Color(0xFFFF8A9A), Color(0x26FF6B7D)),
    'Sports': (Color(0xFF6FE0A8), Color(0x263FD68F)),
    'Kids': (Color(0xFFF7CB6B), Color(0x26F5BD4A)),
    'News': (Color(0xFF8DB9FF), Color(0x2672A9FF)),
    'Music': (Color(0xFFD19BFF), Color(0x26B56CFF)),
    'Infotainment': (Color(0xFF6ADFD3), Color(0x262CC5B5)),
    'Devotional': (Color(0xFFE2B98F), Color(0x26C98B54)),
  };

  static (Color, Color) genre(String g) {
    for (final e in genres.entries) {
      if (g.toLowerCase().contains(e.key.toLowerCase())) return e.value;
    }
    return (inkSoft, sunken);
  }
}

/// The accent as a light gradient, for the main button and highlights.
abstract final class G {
  /// Solid accent (kept as a gradient type so it drops into decorations).
  static const accent = LinearGradient(colors: [C.brand, C.brand]);

  /// A soft glow of the accent, laid over a surface.
  /// Kept for compatibility; the design no longer uses glows.
  static RadialGradient glow(Color c, {Alignment at = Alignment.topRight, double strength = 0.22}) =>
      RadialGradient(colors: [c.withValues(alpha: 0), c.withValues(alpha: 0)]);
}

/// Depth: components sit on the page like physical tiles, lit from above
/// with a soft shadow underneath, so each one reads as its own object.
abstract final class D {
  /// Flat design: no shadows. Kept so callers stay simple.
  static const lift = <BoxShadow>[];

  static BoxDecoration card({double radius = R.lg, Color? edge, double edgeWidth = 1, bool lifted = true}) => BoxDecoration(
        color: C.cardTop,
        border: Border.all(color: edge ?? C.cardEdge, width: edgeWidth),
        boxShadow: lifted ? lift : null,
      );

  /// No sheen in the solid style; kept so callers stay simple.
  static BoxDecoration? sheen(double radius) => null;

  /// Pressed into the page: fields and tracks.
  static BoxDecoration inset({double radius = R.md}) => BoxDecoration(
        color: const Color(0xFF0E0E14),
        border: Border.all(color: C.lineStrong),
      );

  /// A raised accent button: gradient face with a darker lip underneath.
  static BoxDecoration accentButton({double radius = R.md, bool pressed = false}) => BoxDecoration(
        color: C.brand,
      );
}

abstract final class S {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const page = 20.0;
}

/// Corners are sharp throughout.
abstract final class R {
  static const sm = 0.0;
  static const md = 0.0;
  static const lg = 0.0;
  static const xl = 0.0;
}

abstract final class T {
  static const _f = 'Manrope';
  static const display = TextStyle(fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6, color: C.ink);
  static const title = TextStyle(fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4, color: C.ink);
  static const section = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2, color: C.ink);
  static const item = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3, color: C.ink);
  static const body = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500, height: 1.45, color: C.inkSoft);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w700, height: 1.25, color: C.ink);
  static const caption = TextStyle(fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.4, color: C.muted);
  static const overline = TextStyle(fontFamily: _f, fontSize: 11, fontWeight: FontWeight.w800, height: 1.3, letterSpacing: 0.8, color: C.muted);
  static const price = TextStyle(fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.4, color: C.ink);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.brand,
      brightness: Brightness.dark,
      primary: C.brand,
      surface: C.surface,
      onSurface: C.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerColor: C.line,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.brand, selectionColor: C.brandSoft, selectionHandleColor: C.brand),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.raised,
      contentTextStyle: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, fontWeight: FontWeight.w600, color: C.ink),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.all(Radius.zero)),
      textStyle: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: C.ink),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// "₹1,517" / "₹113.27" — Indian grouping, paise only when present.
String rupees(num amount, {bool signed = false}) {
  final neg = amount < 0;
  final abs = amount.abs();
  final paise = (abs * 100).round();
  final whole = paise ~/ 100;
  final frac = paise % 100;
  final s = whole.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  final body = frac == 0 ? '₹$grouped' : '₹$grouped.${frac.toString().padLeft(2, '0')}';
  if (!signed || paise == 0) return neg ? '−$body' : body;
  return neg ? '−$body' : '+$body';
}
