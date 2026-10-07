// DishTV Next — the redesigned subscriber app (Home + Change Pack), built
// fresh on mock data. Swap [MockRepository] for a live implementation of
// [Repository] to connect the real APIs.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'app/theme_switch.dart';
import 'data/repository.dart';
import 'state/app_store.dart';
import 'state/plan_store.dart';
import 'ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Light or dark, as last chosen; this also sets the system bars.
  await loadThemeMode();
  runApp(DishTvNext(repo: MockRepository()));
}

class DishTvNext extends StatelessWidget {
  const DishTvNext({super.key, required this.repo});

  final Repository repo;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStore(repo)..load()),
        ChangeNotifierProvider(create: (_) => PlanStore(repo)),
      ],
      child: MaterialApp(
        title: 'DishTV',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Sleek type: text at 90% of its set size, on top of the user's own
        // text size, but never under 11 pt (scaled the same way).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: SleekTextScaler(mq.textScaler)),
            // Cross-fades the whole app when light/dark is switched.
            child: ThemeFade(child: _Responsive(child: child!)),
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}

/// On tablets and landscape phones, keeps the app at a comfortable phone-like
/// width, centred, so every screen keeps its layout instead of stretching.
/// Screens read the narrowed size from MediaQuery, so their own responsive
/// checks still work.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.child});

  final Widget child;

  static const maxWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;
    // Side insets (e.g. a landscape notch) don't reach the centred column.
    EdgeInsets noSides(EdgeInsets e) => e.copyWith(left: 0, right: 0);
    return ColoredBox(
      color: C.bg,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(maxWidth, mq.size.height),
              padding: noSides(mq.padding),
              viewPadding: noSides(mq.viewPadding),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 90% of the user's text size, with an 11 pt floor (Apple's smallest
/// legible size), applied per font size so iOS's own non-linear Dynamic
/// Type curve is kept.
@immutable
class SleekTextScaler extends TextScaler {
  const SleekTextScaler(this.user);

  /// The device's text size setting.
  final TextScaler user;

  static const _shrink = 0.9;
  static const _floor = 11.0;

  @override
  double scale(double fontSize) => math.max(user.scale(fontSize) * _shrink, user.scale(math.min(fontSize, _floor)));

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => user.textScaleFactor * _shrink;

  @override
  bool operator ==(Object other) => other is SleekTextScaler && other.user == user;

  @override
  int get hashCode => user.hashCode;
}
