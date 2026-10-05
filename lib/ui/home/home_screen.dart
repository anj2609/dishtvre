// Home: who you are, your connections, four quick actions and one offer.
// Everything else lives one tap away in All services, so Home stays calm.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/change_pack_screen.dart';
import '../change_pack/plan_screen.dart';
import '../add_remove/add_remove_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'all_services_screen.dart';
import 'app_drawer.dart';
import 'connection_card.dart';
import 'profile_screen.dart';

void comingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming in the next phase of the redesign.')));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = PageController(viewportFraction: 0.9);
  int _nav = 0;
  bool _planRequested = false;
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppStore>();
      if (s.connections.isEmpty) s.load();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning,' : (h < 17 ? 'Good afternoon,' : 'Good evening,');
  }

  bool _searching = false;
  final _searchFocus = FocusNode();

  // Open or close the search bar; opening focuses the field and raises the keyboard.
  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocus.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    } else {
      _searchFocus.unfocus();
    }
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  // My Pack: what's in the selected TV's plan.
  void _myPack() {
    final c = context.read<AppStore>().connection;
    if (c != null) context.read<PlanStore>().open(c);
    _open(const PlanScreen(readOnly: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final plan = context.watch<PlanStore>();
    // Load the selected TV's plan once so Home can show its channels.
    if (plan.connection == null && s.connection != null && !_planRequested) {
      _planRequested = true;
      final c = s.connection!;
      WidgetsBinding.instance.addPostFrameCallback((_) => plan.open(c));
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: _scaffold,
        drawer: const AppDrawer(),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Expanded(
              child: Stack(children: [
                RefreshIndicator(
                  color: C.brand,
                  onRefresh: s.load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: S.xxl),
                    children: [
                      _topBar(s),
                      Reveal(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, S.lg),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_greeting, style: T.body.copyWith(fontSize: 13, color: C.muted)),
                            Text(s.subscriber?.name ?? '', style: T.title.copyWith(fontSize: 20, height: 1.2)),
                          ]),
                        ),
                      ),
                      // Always one child here, so the list below never shifts.
                      AnimatedSize(duration: const Duration(milliseconds: 180), alignment: Alignment.topCenter, child: _searching ? _searchBar() : const SizedBox(width: double.infinity)),
                      if (s.loading && s.connections.isEmpty) const Skeleton(height: 240) else Reveal(order: 2, child: _connections(s)),
                      Reveal(order: 3, child: _quickActions()),
                      Reveal(order: 4, child: _onYourTv(plan)),
                      Reveal(order: 5, child: _offer()),
                    ],
                  ),
                ),
              ]),
            ),
            _bottomNav(),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(AppStore s) => Padding(
        padding: const EdgeInsets.fromLTRB(S.lg, S.sm, S.lg, 0),
        child: Row(children: [
          RoundIconButton(icon: Icons.menu_sharp, label: 'Menu', onTap: () => _scaffold.currentState?.openDrawer()),
          const SizedBox(width: S.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('dishtv', style: T.title.copyWith(color: C.brand, fontSize: 24, letterSpacing: -0.8)),
              ),
            ),
          ),
          _plainIcon(Icons.search_sharp, _searching ? 'Close search' : 'Search', _toggleSearch, color: _searching ? C.brand : C.ink),
          _plainIcon(Icons.notifications_none_sharp, 'Notifications', () => comingSoon(context, 'Notifications'), badge: true),
          const SizedBox(width: 4),
          // Your photo (or initials); opens Profile.
          Tooltip(
            message: 'Profile',
            child: InkResponse(
              onTap: s.subscriber == null ? null : () => _open(const ProfileScreen()),
              radius: 24,
              child: Avatar(initials: s.subscriber?.initials ?? '', photo: s.subscriber?.photo, size: 40),
            ),
          ),
        ]),
      );

  // Search bar, shown when the search icon is tapped: orange outline,
  // search icon, a text field and a mic.
  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: S.md + 2),
          decoration: BoxDecoration(color: C.sunken, border: Border.all(color: C.brand, width: 1.2)),
          child: Row(children: [
            const Icon(Icons.search_sharp, size: 22, color: C.brand),
            const SizedBox(width: S.md),
            Expanded(
              child: TextField(
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => comingSoon(context, 'Search'),
                style: T.body.copyWith(fontSize: 15, color: C.ink),
                cursorColor: C.brand,
                decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Search services, packs, help...', hintStyle: T.body.copyWith(fontSize: 15, color: C.muted)),
              ),
            ),
            Tooltip(
              message: 'Voice search',
              child: InkResponse(
                onTap: () => comingSoon(context, 'Voice search'),
                radius: 24,
                child: const SizedBox(width: 52, height: 52, child: Icon(Icons.mic_none_sharp, size: 24, color: C.ink)),
              ),
            ),
          ]),
        ),
      );

  Widget _plainIcon(IconData icon, String label, VoidCallback onTap, {bool badge = false, Color color = C.ink}) => Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: 22, color: color),
              if (badge)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: C.brand, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 1.5)),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _connections(AppStore s) {
    if (s.connections.isEmpty) return const SizedBox.shrink();
    final multi = s.connections.length > 1;
    final cardWidth = MediaQuery.sizeOf(context).width * 0.9 - S.page - 6;
    // The carousel is as tall as its tallest card: every card is laid out
    // invisibly at the real width to size the Stack, and the PageView sits
    // on top. Works at any text size without clipping.
    return Column(children: [
      // Full width: the PageView's pages are a fraction of this.
      SizedBox(
          width: double.infinity,
          child: Stack(children: [
            IgnorePointer(
              child: ExcludeSemantics(
                child: Visibility.maintain(
                  visible: false,
                  child: Padding(
                    // A few px of slack for rounding between page widths.
                    padding: const EdgeInsets.fromLTRB(S.page, 4, 0, 18),
                    child: Stack(children: [
                      for (final c in s.connections) SizedBox(width: cardWidth, child: ConnectionCard(c: c, onRecharge: () {})),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                padEnds: !multi,
                itemCount: s.connections.length,
                onPageChanged: s.select,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.fromLTRB(i == 0 ? S.page : 6, 4, 6, 14),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConnectionCard(c: s.connections[i], onRecharge: () => comingSoon(context, 'Recharge')),
                  ),
                ),
              ),
            ),
          ])),
      if (multi)
        AnimatedBuilder(
          animation: _pages,
          builder: (_, __) {
            final p = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? 0) : 0.0;
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < s.connections.length; i++)
                Builder(builder: (_) {
                  final t = (1 - (p - i).abs()).clamp(0.0, 1.0);
                  final (accent, _) = accentOf(s.connections[i].status);
                  return Container(
                    width: 6 + 14 * t,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: Color.lerp(C.lineStrong, accent, t), borderRadius: BorderRadius.circular(3)),
                  );
                }),
            ]);
          },
        ),
    ]);
  }

  Widget _quickActions() {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.layers_sharp, 'Change Pack', () => _open(const ChangePackScreen())),
      (Icons.add_to_queue_sharp, 'Add/Remove Channel', () => _open(const AddRemoveScreen())),
      (Icons.live_tv_sharp, 'My Pack', _myPack),
      (Icons.apps_sharp, 'All Services', () => _open(const AllServicesScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, a) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: S.md),
          Expanded(
            child: Pressable(
              label: a.$2,
              onTap: a.$3,
              child: Column(children: [
                // Just the white icon: no fill, no border.
                SizedBox(height: 48, child: Center(child: Icon(a.$1, color: C.ink, size: 36))),
                const SizedBox(height: S.sm),
                Text(a.$2, textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 12.5)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // Logos of the channels on the TV whose plan is loaded.
  Widget _onYourTv(PlanStore plan) {
    final base = plan.basePack;
    if (plan.connection == null || base == null) return const SizedBox.shrink();
    return FutureBuilder<List<Channel>>(
      future: plan.currentChannels(),
      builder: (context, snap) {
        final logos = showcase(snap.data ?? const [], 14);
        if (logos.isEmpty) return const SizedBox(height: 130);
        return Padding(
          padding: const EdgeInsets.only(top: S.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.page),
              child: Row(children: [
                Expanded(child: Text('On your TV', style: T.section.copyWith(fontSize: 17))),
                Text('${base.channels} channels', style: T.caption),
              ]),
            ),
            const SizedBox(height: S.md),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(S.page, 4, S.page, 8),
                itemCount: logos.length,
                separatorBuilder: (_, __) => const SizedBox(width: S.md),
                itemBuilder: (_, i) => Pressable(
                  label: logos[i].$1,
                  onTap: () => comingSoon(context, 'Channel guide'),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: D.lift),
                    child: ChannelLogo(name: logos[i].$1, url: logos[i].$2, size: 58),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _offer() {
    final narrow = MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(10) > 13;
    final info = Row(children: [
      // The offer's app, with its real logo.
      const AppLogo(name: 'Sony LIV', url: 'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/dishsmartottapps/sonyliv.webp', size: 52),
      const SizedBox(width: S.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stream shows & live sports', style: T.caption),
          Text('Sony LIV Premium', style: T.item),
          Text('₹49/month', style: T.label.copyWith(color: C.brandDeep)),
        ]),
      ),
    ]);
    final button = Material(
      color: C.ink,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => comingSoon(context, 'OTT offers'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text('Activate', textAlign: TextAlign.center, style: T.label.copyWith(color: C.onInk)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.xxl, S.page, 0),
      child: Glow(
        color: const Color(0xFF3B2F86),
        strength: 1,
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(S.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('OFFER FOR YOU', style: T.overline.copyWith(color: const Color(0xFFB9A8FF))),
              const SizedBox(height: S.sm),
              narrow
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: S.md), button])
                  : Row(children: [Expanded(child: info), const SizedBox(width: S.sm), button]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bottomNav() {
    const items = [
      (Icons.home_sharp, 'Home'),
      (Icons.live_tv_sharp, 'TV on the go'),
      (Icons.currency_rupee_sharp, 'Recharge'),
      (Icons.play_circle_outline_sharp, 'OTT'),
      (Icons.support_agent_sharp, 'Get help'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.cardEdge)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
      child: Row(children: [
        for (final (i, it) in items.indexed)
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              selected: i == _nav,
              label: it.$2,
              child: InkWell(
                onTap: () {
                  if (i == 0) return setState(() => _nav = 0);
                  comingSoon(context, it.$2);
                },
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      
                      child: Icon(it.$1, size: 22, color: C.ink),
                    ),
                    const SizedBox(height: 3),
                    // One line, never broken mid-word: shrinks to fit instead.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(it.$2,
                            maxLines: 1,
                            softWrap: false,
                            style: T.caption
                                .copyWith(fontSize: 11, fontWeight: i == _nav ? FontWeight.w800 : FontWeight.w600, color: i == _nav ? C.ink : C.muted)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
