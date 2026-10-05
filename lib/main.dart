// DishTV Next — the redesigned subscriber app (Home + Change Pack), built
// fresh on mock data. Swap [MockRepository] for a live implementation of
// [Repository] to connect the real APIs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'data/repository.dart';
import 'state/app_store.dart';
import 'state/plan_store.dart';
import 'ui/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: C.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
        builder: (context, child) => _Responsive(child: child!),
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
