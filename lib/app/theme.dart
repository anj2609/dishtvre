// Design tokens for DishTV Next, in two modes: "Midnight" (dark) and
// "Paper" (light).
//
// Dark is a sleek stage like a streaming app: near-black ground, solid
// charcoal cards. Light is calm and professional: a soft grey ground with
// white cards and near-black type. Both have crisp edges and sharp corners,
// and the orange card gradient for the main action. Every screen reads
// colours, type, spacing and radii from here, so both modes stay in step.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Light or dark. Flipped by the toggle on Home and remembered between
/// launches; the app rebuilds every screen when it changes.
final lightMode = ValueNotifier<bool>(false);

bool get _l => lightMode.value;

/// Colours for the current mode. Dark is "Midnight": near-black ground with
/// charcoal surfaces. Light is "Paper": a soft grey ground with white
/// surfaces, near-black type and deeper status colours so everything keeps
/// its contrast on white.
abstract final class C {
  // Ground and surfaces. Dark: darkest to lightest. Light: the page is a
  // soft grey and surfaces are white, so cards lift off it without shadows.
  static Color get bg => _l ? const Color(0xFFF3F3F6) : const Color(0xFF08080C);
  static Color get sunken => _l ? const Color(0xFFEBEBF0) : const Color(0xFF111117);
  static Color get surface => _l ? const Color(0xFFFFFFFF) : const Color(0xFF18181F);
  static Color get raised => _l ? const Color(0xFFEDEDF2) : const Color(0xFF24242F);
  static Color get line => _l ? const Color(0xFFE5E5EB) : const Color(0xFF26262F);
  static Color get lineStrong => _l ? const Color(0xFFD2D2DB) : const Color(0xFF383845);

  // Cards: one solid shade, clearly apart from the page.
  static Color get cardTop => _l ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E29);
  static Color get cardBottom => _l ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E29);
  static Color get cardEdge => _l ? const Color(0xFFE1E1E8) : const Color(0xFF34343F);

  // One solid colour per feature, so each is recognisable at a glance.
  static const explore = Color(0xFFE85A2C);
  static const ai = Color(0xFF6656E0);
  static const addOns = Color(0xFF0E9488);

  // Text.
  static Color get ink => _l ? const Color(0xFF14141B) : const Color(0xFFF4F4F8);
  static Color get inkSoft => _l ? const Color(0xFF41414E) : const Color(0xFFC9C9D4);
  static Color get muted => _l ? const Color(0xFF6E6E7F) : const Color(0xFF8E8EA2);
  static Color get faint => _l ? const Color(0xFFA4A4B2) : const Color(0xFF5E5E71);

  /// Text on an [ink] fill.
  static Color get onInk => _l ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B11);

  // Accent: a touch deeper on white so orange text stays readable.
  static Color get brand => _l ? const Color(0xFFEA5B2A) : const Color(0xFFFF6A3D);
  static Color get brandDark => _l ? const Color(0xFFB4421B) : const Color(0xFFC4441F);
  static Color get brandDeep => _l ? const Color(0xFFC2461C) : const Color(0xFFFF9B78);
  static const brandSoft = Color(0x00000000);
  static const brandTint = Color(0x00000000);

  // Status: muted on the dark ground, deeper on white.
  static Color get success => _l ? const Color(0xFF1C8753) : const Color(0xFF63BF8E);
  static const successSoft = Color(0x00000000);
  static Color get warning => _l ? const Color(0xFFB0741A) : const Color(0xFFE2B45A);
  static const warningSoft = Color(0x00000000);
  static Color get danger => _l ? const Color(0xFFD23C4C) : const Color(0xFFF07C88);
  static const dangerSoft = Color(0x00000000);
  static Color get info => _l ? const Color(0xFF2C68CF) : const Color(0xFF7FA8F0);
  static const infoSoft = Color(0x00000000);

  // Connection states.
  static Color get vacation => _l ? const Color(0xFF2C68CF) : const Color(0xFF7FA8F0);
  static const vacationSoft = Color(0x00000000);
  static Color get off => _l ? const Color(0xFF7A7A8C) : const Color(0xFF9696A8);
  static const offSoft = Color(0x00000000);

  // Kept for the few places that sit on a lit stage.
  static Color get night => bg;
  static Color get nightRaised => surface;
  static Color get onNight => ink;
  static Color get onNightMuted => muted;
  static const glass = Color(0x00000000);
  static Color get glassLine => _l ? const Color(0x1A000000) : const Color(0x1FFFFFFF);
  static const magenta = Color(0xFFFF4D7E);
  static const violet = Color(0xFF8B6CFF);
  static const teal = Color(0xFF2CC5B5);
  static const cobalt = Color(0xFF4F7DFF);

  /// A faint wash of the ink colour: white on dark, black on light. For
  /// hairlines and overlays that must work on both grounds.
  static Color wash(double alpha) => (_l ? Colors.black : Colors.white).withValues(alpha: alpha);

  // Genre accents (text, background).
  static Map<String, (Color, Color)> get genres => _l ? _genresLight : _genresDark;
  static const _genresDark = <String, (Color, Color)>{
    'Entertainment': (Color(0xFFFF9B78), Color(0x26FF6A3D)),
    'Movies': (Color(0xFFFF8A9A), Color(0x26FF6B7D)),
    'Sports': (Color(0xFF6FE0A8), Color(0x263FD68F)),
    'Kids': (Color(0xFFF7CB6B), Color(0x26F5BD4A)),
    'News': (Color(0xFF8DB9FF), Color(0x2672A9FF)),
    'Music': (Color(0xFFD19BFF), Color(0x26B56CFF)),
    'Infotainment': (Color(0xFF6ADFD3), Color(0x262CC5B5)),
    'Devotional': (Color(0xFFE2B98F), Color(0x26C98B54)),
  };
  static const _genresLight = <String, (Color, Color)>{
    'Entertainment': (Color(0xFFC2461C), Color(0x1AFF6A3D)),
    'Movies': (Color(0xFFC2304A), Color(0x1AFF6B7D)),
    'Sports': (Color(0xFF1C8753), Color(0x1A3FD68F)),
    'Kids': (Color(0xFF9A6A0E), Color(0x1FF5BD4A)),
    'News': (Color(0xFF2C68CF), Color(0x1A72A9FF)),
    'Music': (Color(0xFF7B3FC4), Color(0x1AB56CFF)),
    'Infotainment': (Color(0xFF13877C), Color(0x1A2CC5B5)),
    'Devotional': (Color(0xFF94602F), Color(0x1AC98B54)),
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
  static LinearGradient get accent => LinearGradient(colors: [C.brand, C.brand]);

  /// The DishTV orange for every orange fill in the app: the Home card's
  /// gradient, bright orange top-left melting into a deep burnt orange
  /// bottom-right.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.45, 1],
    colors: [Color(0xFFE86A38), Color(0xFFC9542A), Color(0xFF94401F)],
  );

  /// The card gradient for orange text and icons: the same direction and
  /// feel, but it stops at a deep orange instead of the card's maroon so
  /// thin strokes stay readable (a shade deeper on the light ground).
  static LinearGradient get brandInk => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _l ? const [Color(0xFFF26A35), Color(0xFFD9541F), Color(0xFFA9401A)] : const [Color(0xFFFF8A5B), Color(0xFFE5622E), Color(0xFFC24A22)],
      );

  /// The same card effect for any other solid colour block.
  static LinearGradient card(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.45, 1],
        colors: [Color.lerp(c, Colors.white, 0.1)!, c, Color.lerp(c, Colors.black, 0.45)!],
      );

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

  /// A quiet surface: background contrast instead of an outline. An
  /// outline appears only when [edge] is given (e.g. to mark a selection).
  static BoxDecoration card({double radius = R.lg, Color? edge, double edgeWidth = 1, bool lifted = true}) => BoxDecoration(
        color: C.surface,
        border: edge == null ? null : Border.all(color: edge, width: edgeWidth),
        boxShadow: lifted ? lift : null,
      );

  /// No sheen in the solid style; kept so callers stay simple.
  static BoxDecoration? sheen(double radius) => null;

  /// Pressed into the page: fields and tracks.
  static BoxDecoration inset({double radius = R.md}) => BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.line),
      );

  /// A raised accent button: gradient face with a darker lip underneath.
  static BoxDecoration accentButton({double radius = R.md, bool pressed = false}) => const BoxDecoration(
        gradient: G.brand,
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
  // Sleek: one step lighter than bold throughout. (Sizes are scaled down a
  // touch app-wide in main.dart.)
  static TextStyle get display => TextStyle(fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6, color: C.ink);
  static TextStyle get title => TextStyle(fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, color: C.ink);
  static TextStyle get section => TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.2, color: C.ink);
  static TextStyle get item => TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: C.ink);
  static TextStyle get body => TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500, height: 1.45, color: C.inkSoft);
  static TextStyle get label => TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w600, height: 1.25, color: C.ink);
  static TextStyle get caption => TextStyle(fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.4, color: C.muted);
  static TextStyle get overline => TextStyle(fontFamily: _f, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: 0.8, color: C.muted);
  static TextStyle get price => TextStyle(fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.4, color: C.ink);
}

ThemeData buildTheme() {
  final brightness = _l ? Brightness.light : Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.brand,
      brightness: brightness,
      primary: C.brand,
      surface: C.surface,
      onSurface: C.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerColor: C.line,
    textSelectionTheme: TextSelectionThemeData(cursorColor: C.brand, selectionColor: const Color(0x55FF6A3D), selectionHandleColor: C.brand),
  );
  // Snackbars and tooltips stay dark in both modes: a crisp dark chip reads
  // best on white too.
  const chip = Color(0xFF1D1D25);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _l ? chip : C.raised,
      contentTextStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFFF4F4F8)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: _l ? chip : C.raised, borderRadius: BorderRadius.zero),
      textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 12, color: Color(0xFFF4F4F8)),
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
