// Light and dark. Until you pick one, the app matches the iPhone's own
// setting and follows it when it changes; a pick is remembered between
// launches. When it flips, every screen rebuilds with the new colours
// while a snapshot of the old look fades out on top, so the change is a
// soft cross-fade, not a flash.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const _key = 'light_mode';

/// True while there's no saved pick: the app matches the iPhone's setting.
final followSystem = ValueNotifier<bool>(true);

bool get _systemLight => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light;

/// Reads the saved mode (or the iPhone's, if none); call before the app
/// starts.
Future<void> loadThemeMode() async {
  bool? saved;
  try {
    final prefs = await SharedPreferences.getInstance();
    saved = prefs.getBool(_key);
  } catch (_) {
    // Nothing saved: follow the system.
  }
  followSystem.value = saved == null;
  lightMode.value = saved ?? _systemLight;
  SystemChrome.setSystemUIOverlayStyle(systemBars);
}

/// Goes back to matching the iPhone's setting, and forgets the pick.
Future<void> useSystemTheme() async {
  followSystem.value = true;
  SharedPreferences.getInstance().then((p) => p.remove(_key)).catchError((_) => false);
  if (lightMode.value != _systemLight) await _flipWithFade(save: false);
  _rebuildEverything();
}

/// Picks light or dark for good (until changed again).
Future<void> setLightMode(bool light) async {
  if (lightMode.value != light) {
    await _flipWithFade();
  } else {
    followSystem.value = false;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, light)).catchError((_) => false);
    _rebuildEverything();
  }
}

/// Status and navigation bars to match the mode.
SystemUiOverlayStyle get systemBars {
  final light = lightMode.value;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
    statusBarBrightness: light ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: C.surface,
    systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
  );
}

/// Switches between light and dark (and remembers it), with a cross-fade
/// when [ThemeFade] is in the tree.
Future<void> toggleLightMode() => _flipWithFade();

Future<void> _flipWithFade({bool save = true}) async {
  final fade = _ThemeFadeState._current;
  if (fade != null) {
    await fade.flip(save: save);
  } else {
    _flip(save: save);
  }
}

/// [save]: a pick (remembered, stops following the system), or false when
/// following the iPhone's setting.
void _flip({bool save = true}) {
  lightMode.value = !lightMode.value;
  if (save) {
    followSystem.value = false;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, lightMode.value)).catchError((_) => false);
  }
  SystemChrome.setSystemUIOverlayStyle(systemBars);
  _rebuildEverything();
}

/// Colours are read while building and painting, so a mode change needs
/// every widget rebuilt and repainted, including ones that are const.
void _rebuildEverything() {
  void visit(Element e) {
    e.markNeedsBuild();
    if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

/// Wraps the app so a mode change cross-fades from the old look.
class ThemeFade extends StatefulWidget {
  const ThemeFade({super.key, required this.child});
  final Widget child;

  @override
  State<ThemeFade> createState() => _ThemeFadeState();
}

class _ThemeFadeState extends State<ThemeFade> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static _ThemeFadeState? _current;

  final _boundary = GlobalKey();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  ui.Image? _shot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _current = this;
    WidgetsBinding.instance.addObserver(this);
  }

  /// The iPhone switched light/dark: follow it, unless a pick was made.
  @override
  void didChangePlatformBrightness() {
    if (followSystem.value && lightMode.value != _systemLight) flip(save: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_current == this) _current = null;
    _fade.dispose();
    _shot?.dispose();
    super.dispose();
  }

  Future<void> flip({bool save = true}) async {
    if (_busy) return;
    _busy = true;
    ui.Image? shot;
    if (!MediaQuery.of(context).disableAnimations) {
      try {
        final ro = _boundary.currentContext?.findRenderObject();
        if (ro is RenderRepaintBoundary) shot = await ro.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      } catch (_) {
        // No snapshot: switch without the fade.
      }
    }
    if (!mounted) {
      shot?.dispose();
      _busy = false;
      return;
    }
    setState(() => _shot = shot);
    _flip(save: save);
    if (shot != null) await _fade.forward(from: 0);
    if (mounted) setState(() => _shot = null);
    shot?.dispose();
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Stack(children: [
      RepaintBoundary(key: _boundary, child: widget.child),
      if (shot != null)
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _fade, curve: Curves.easeInOut)),
              child: RawImage(image: shot, fit: BoxFit.fill),
            ),
          ),
        ),
    ]);
  }
}

/// The light/dark switch: a small sharp track with the sun and the moon,
/// and a gradient knob that slides to the mode that's on.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final light = lightMode.value;
    return Semantics(
      toggled: light,
      button: true,
      label: 'Light theme',
      child: Tooltip(
        message: light ? 'Switch to dark' : 'Switch to light',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            toggleLightMode();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: Container(
              width: 54,
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: C.sunken, border: Border.all(color: C.line)),
              child: Stack(children: [
                // The two ends, faint.
                Row(children: [
                  Expanded(child: Icon(Icons.light_mode_outlined, size: 14, color: C.faint)),
                  Expanded(child: Icon(Icons.dark_mode_outlined, size: 14, color: C.faint)),
                ]),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: light ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: 24,
                    height: 22,
                    decoration: const BoxDecoration(gradient: G.brand),
                    child: Icon(light ? Icons.light_mode_sharp : Icons.dark_mode_sharp, size: 14, color: Colors.white),
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
