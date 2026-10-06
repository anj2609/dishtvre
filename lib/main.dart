// DishTV Next — the redesigned subscriber app (Home + Change Pack), built
// fresh on mock data. Swap [MockRepository] for a live implementation of
// [Repository] to connect the real APIs.

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
        // Sleek type: every text in the app at 90% of its set size (on top
        // of the user's own text-size setting).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(14) / 14 * 0.9)),
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
