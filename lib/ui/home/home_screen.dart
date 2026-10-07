// Home: who you are and what needs attention, your TV cards with the channels
// on the one showing, the everyday services in three tabs, and offers.
// Everything else lives one tap away in All services.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../app/theme_switch.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/plan_screen.dart';
import '../add_remove/add_remove_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import '../hd/upgrade_hd_screens.dart';
import '../ott/add_ott_screen.dart';
import '../recharge/recharge_screen.dart';
import 'services.dart';
import 'all_services_screen.dart';
import 'app_drawer.dart';
import 'connection_card.dart';
import 'language_screen.dart';
import 'profile_screen.dart';
import 'support_screen.dart';

void comingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text('$what is coming in the next phase of the redesign.')));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _nav = 0;
  _Tab _tab = _Tab.packs;
  final _pages = PageController(viewportFraction: 0.86);
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
    return h < 12
        ? 'Good morning,'
        : (h < 17 ? 'Good afternoon,' : 'Good evening,');
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

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

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
    // Keep the loaded plan on the selected TV (it can change from other
    // screens too) so the channel strip shows that TV's channels, and on
    // its latest details (a recharge or new pack changes them).
    final sel = s.connection;
    if (sel != null && !identical(plan.connection, sel)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !identical(plan.connection, sel)) plan.open(sel);
      });
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBars,
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
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _topBar(s),
                      Reveal(child: _greetingBlock(s)),
                      // Always one child here, so the list below never shifts.
                      AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.topCenter,
                          child: _searching
                              ? _searchBar()
                              : const SizedBox(width: double.infinity)),
                      if (s.loading && s.connections.isEmpty)
                        const Skeleton(height: 240)
                      else if (s.failed && s.connections.isEmpty)
                        // Nothing loaded: say so, and offer another go.
                        EmptyNote(
                          icon: Icons.cloud_off_sharp,
                          title: 'We couldn\'t load your TVs',
                          body: 'Check your internet connection and try again.',
                          action: 'Try again',
                          onAction: s.load,
                        )
                      else
                        Reveal(
                            order: 2,
                            child: Column(children: [
                              _connections(s),
                              _channelStrip(s, plan)
                            ])),
                      Reveal(order: 3, child: _services()),
                      Reveal(order: 4, child: _offer(s)),
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

  /// Menu, wordmark, and four actions at one size and stroke. No circle
  /// behind the menu, so nothing in the bar is heavier than the logo.
  Widget _topBar(AppStore s) => Padding(
        padding: const EdgeInsets.fromLTRB(S.sm, S.md, S.page, 0),
        child: Row(children: [
          _plainIcon(Icons.menu_sharp, 'Menu',
              () => _scaffold.currentState?.openDrawer()),
          const SizedBox(width: 2),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BrandShade(child: Text('dishtv',
                    style: T.title.copyWith(
                        color: C.brand, fontSize: 24, letterSpacing: -0.8))),
              ),
            ),
          ),
          _plainIcon(Icons.search_sharp, _searching ? 'Close search' : 'Search',
              _toggleSearch,
              color: _searching ? C.brand : C.ink),
          _plainIcon(Icons.translate_sharp, 'Choose language',
              () => _open(const LanguageScreen())),
          _plainIcon(Icons.notifications_none_sharp, 'Notifications',
              () => comingSoon(context, 'Notifications'),
              badge: true),
          const SizedBox(width: 6),
          // Your photo (or initials); opens Profile.
          Tooltip(
            message: 'Profile',
            child: InkResponse(
              onTap: s.subscriber == null
                  ? null
                  : () => _open(const ProfileScreen()),
              radius: 22,
              child: Avatar(
                  initials: s.subscriber?.initials ?? '',
                  photo: s.subscriber?.photo,
                  size: 36),
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
          decoration: BoxDecoration(
              color: C.sunken, border: Border.all(color: C.brand, width: 1.2)),
          child: Row(children: [
            BrandShade(child: Icon(Icons.search_sharp, size: 22, color: C.brand)),
            const SizedBox(width: S.md),
            Expanded(
              child: TextField(
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => comingSoon(context, 'Search'),
                style: T.body.copyWith(fontSize: 15, color: C.ink),
                cursorColor: C.brand,
                decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search services, packs, help...',
                    hintStyle: T.body.copyWith(fontSize: 15, color: C.muted)),
              ),
            ),
            Tooltip(
              message: 'Voice search',
              child: InkResponse(
                onTap: () => comingSoon(context, 'Voice search'),
                radius: 24,
                child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.mic_none_sharp, size: 24, color: C.ink)),
              ),
            ),
          ]),
        ),
      );

  Widget _plainIcon(IconData icon, String label, VoidCallback onTap,
          {bool badge = false, Color? color}) =>
      Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              BrandShade(on: color == C.brand, child: Icon(icon, size: 22, color: color ?? C.ink)),
              if (badge)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        gradient: G.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.bg, width: 1.5)),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _connections(AppStore s) {
    if (s.connections.isEmpty) return const SizedBox.shrink();
    final multi = s.connections.length > 1;
    final cardWidth = MediaQuery.sizeOf(context).width * 0.86 - 12;
    // How far a centred card's edge sits inside the page margin.
    final edgeGap = MediaQuery.sizeOf(context).width * 0.07 + 6 - S.page;
    // If the TV was changed on another screen, bring its card into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || !_pages.position.haveDimensions)
        return;
      if (_pages.position.isScrollingNotifier.value) return;
      if ((_pages.page ?? 0).round() != s.selectedIndex)
        _pages.jumpToPage(s.selectedIndex);
    });
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
                      for (final c in s.connections)
                        SizedBox(
                            width: cardWidth,
                            child: ConnectionCard(c: c, onRecharge: () {})),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                padEnds: true,
                itemCount: s.connections.length,
                onPageChanged: s.select,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
                  // The card in view sits centred at full size; a slice of the
                  // cards on either side shows, smaller and dimmer, and zooms
                  // in as you swipe it to the middle.
                  child: AnimatedBuilder(
                    animation: _pages,
                    builder: (_, child) {
                      final p =
                          _pages.hasClients && _pages.position.haveDimensions
                              ? (_pages.page ?? 0)
                              : s.selectedIndex.toDouble();
                      final d = (p - i).abs().clamp(0.0, 1.0);
                      // On the first card, slide everything left so it lines
                      // up with the page margin (nothing sits to its left);
                      // on the last, slide right. Middle cards stay centred.
                      final n = s.connections.length;
                      final shift = n < 2
                          ? 0.0
                          : -edgeGap * (1 - p.clamp(0.0, 1.0)) +
                              edgeGap * (p - (n - 2)).clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(shift, 0),
                        child: Opacity(
                          opacity: 1 - 0.6 * d,
                          child: Transform.scale(
                              scale: 1 - 0.08 * d,
                              alignment: Alignment.center,
                              child: child),
                        ),
                      );
                    },
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConnectionCard(
                          c: s.connections[i],
                          onRecharge: () {
                            s.select(i);
                            _open(const RechargeScreen());
                          }),
                    ),
                  ),
                ),
              ),
            ),
          ])),
      if (multi)
        AnimatedBuilder(
          animation: _pages,
          builder: (_, __) {
            final p = _pages.hasClients && _pages.position.haveDimensions
                ? (_pages.page ?? 0)
                : 0.0;
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < s.connections.length; i++)
                Builder(builder: (_) {
                  final t = (1 - (p - i).abs()).clamp(0.0, 1.0);
                  final (accent, _) = accentOf(s.connections[i].status);
                  // The active TV's dot takes the card gradient once it's the one in view.
                  final orange = s.connections[i].status == ConnectionStatus.active && t > 0.5;
                  return Container(
                    width: 6 + 14 * t,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        color: orange ? null : Color.lerp(C.lineStrong, accent, t),
                        gradient: orange ? G.brand : null,
                        borderRadius: BorderRadius.circular(3)),
                  );
                }),
            ]);
          },
        ),
    ]);
  }

  /// The channels on the TV whose card is showing, right under the cards:
  /// a one-line heading and same-size logos gliding by, faded at the edges.
  /// Tap it for the guide.
  Widget _channelStrip(AppStore s, PlanStore plan) {
    final c = s.connection;
    if (c == null) return const SizedBox.shrink();
    final base = plan.connection?.vc == c.vc ? plan.basePack : null;
    return Padding(
      padding: const EdgeInsets.only(top: S.xl),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: base == null
            ? const SizedBox(key: ValueKey('loading'), height: 92)
            : FutureBuilder<List<Channel>>(
                key: ValueKey(c.vc),
                future: plan.currentChannels(),
                builder: (context, snap) {
                  final logos = showcase(snap.data ?? const [], 14);
                  return Pressable(
                    label:
                        'Channels on ${c.label}: ${base.channels}. Open channel guide',
                    onTap: () => comingSoon(context, 'Channel guide'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: S.page),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  // One run of text, so with large type the
                                  // count wraps under the name by words.
                                  Expanded(
                                    child: Text.rich(TextSpan(children: [
                                      TextSpan(
                                          text: 'On ${c.label}  ',
                                          style: T.section.copyWith(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      TextSpan(
                                          text: '${base.channels} channels',
                                          style: T.caption.copyWith(
                                              fontSize: 12, color: C.faint)),
                                    ])),
                                  ),
                                  // Text and arrow as one inline run, so they
                                  // share the heading's baseline.
                                  Text.rich(TextSpan(children: [
                                    TextSpan(
                                        text: 'Guide',
                                        style: T.label.copyWith(
                                            fontSize: 12.5, color: C.inkSoft)),
                                    WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: BrandShade(child: Icon(Icons.chevron_right_sharp,
                                            color: C.brand, size: 18))),
                                  ])),
                                ]),
                          ),
                          const SizedBox(height: S.lg),
                          logos.isEmpty
                              ? const SizedBox(height: 52)
                              : EdgeFade(
                                  width: 0.06,
                                  child: LogoMarquee(
                                      logos: logos,
                                      size: 52,
                                      gap: 14,
                                      speed: 22)),
                        ]),
                  );
                },
              ),
      ),
    );
  }

  /// Greeting, name, and one quiet line on what needs attention most: a TV
  /// that has already stopped, else the first live TV running out within
  /// five days (the action is the tappable part), or that all is fine.
  Widget _greetingBlock(AppStore s) {
    final now = DateTime.now();
    final stopped = s.connections.where((c) => c.status == ConnectionStatus.deactivated).toList();
    final urgent = stopped.isNotEmpty
        ? stopped
        : (s.connections.where((c) => c.status == ConnectionStatus.active && c.daysLeft(now) <= 5).toList()
          ..sort((a, b) => a.daysLeft(now).compareTo(b.daysLeft(now))));
    final n = s.connections.length;
    final quiet = T.caption.copyWith(fontSize: 12.5, color: C.muted);
    Widget line;
    if (urgent.isNotEmpty) {
      final d = urgent.first.daysLeft(now);
      line = Text.rich(TextSpan(style: quiet, children: [
        TextSpan(
            text: stopped.isNotEmpty
                ? '${urgent.first.label} has stopped.  '
                : '${urgent.first.label} stops ${d <= 0 ? 'today' : 'in $d ${d == 1 ? 'day' : 'days'}'}.  '),
        TextSpan(
          text: stopped.isNotEmpty ? 'Recharge to restart' : 'Recharge to keep watching',
          // Painted with the brand gradient, not a flat orange.
          style: quiet.copyWith(
            color: null,
            foreground: Paint()..shader = G.brandInk.createShader(const Rect.fromLTWH(0, 0, 190, 16)),
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              s.selectVc(urgent.first.vc);
              _open(const RechargeScreen());
            },
        ),
      ]));
    } else {
      line = Text(n == 1 ? 'Your TV is active.' : 'All $n TVs are up to date.',
          style: quiet);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, S.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting, style: T.body.copyWith(fontSize: 13, color: C.muted)),
        const SizedBox(height: 2),
        Text(s.subscriber?.name ?? '',
            style: T.title.copyWith(
                fontSize: 24, height: 1.15, fontWeight: FontWeight.w700)),
        if (n > 0) ...[const SizedBox(height: 6), line],
      ]),
    );
  }

  /// The services, grouped as in All services: Packs & OTT, Recharge &
  /// Offers, Account & Support. White line icons on dark tiles.
  Widget _services() {
    final group = serviceGroups(context, open: _open, myPack: _myPack)[_tab.index];
    // Home shows the first three of each group; the rest are one tap away.
    final items = group.take(3).toList();
    const names = {
      _Tab.packs: 'Packs & OTT',
      _Tab.recharge: 'Recharge & Offers',
      _Tab.account: 'Account & Support'
    };
    final more = group.length - 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.xxl + 4, S.page, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _HomeTabs<_Tab>(
          options: const [
            (_Tab.packs, 'Packs & OTT'),
            (_Tab.recharge, 'Recharge & Offers'),
            (_Tab.account, 'Account & Support')
          ],
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: S.md),
        // One panel: three actions side by side, then "More in …" under them.
        Container(
          color: C.surface,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current]),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(a),
                    child: child),
              ),
              child: IntrinsicHeight(
                key: ValueKey(_tab),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, it) in items.indexed) ...[
                        if (i > 0)
                          Padding(
                              padding: EdgeInsets.symmetric(vertical: S.lg),
                              child: VerticalDivider(
                                  width: 1, thickness: 1, color: C.line)),
                        Expanded(
                            child: Reveal(
                                order: i,
                                child: _ServiceTile(
                                    icon: it.$1, label: it.$2, onTap: it.$3))),
                      ],
                    ]),
              ),
            ),
            Divider(
                height: 1,
                thickness: 1,
                color: C.line,
                indent: S.lg,
                endIndent: S.lg),
            // More in this group: the whole row opens All services on the same tab.
            Semantics(
              button: true,
              label: 'More ${names[_tab]} services, $more more',
              child: InkWell(
                onTap: () => _open(AllServicesScreen(initialTab: _tab.index)),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(S.lg, 14, S.md, 14),
                    child: Row(children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current
                              ]),
                          child: Text('More in ${names[_tab]}',
                              key: ValueKey(_tab),
                              style: T.label
                                  .copyWith(fontSize: 13, color: C.inkSoft)),
                        ),
                      ),
                      Text('$more more',
                          style:
                              T.caption.copyWith(fontSize: 12, color: C.faint)),
                      const SizedBox(width: 2),
                      BrandShade(child: Icon(Icons.chevron_right_sharp,
                          color: C.brand, size: 20)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  /// A few offers that take turns in one card below the services. Go HD
  /// shows only for a TV that isn't on HD yet.
  Widget _offer(AppStore s) => Padding(
        padding: const EdgeInsets.fromLTRB(S.page, S.xxl + 4, S.page, 0),
        child: _OfferCarousel(offers: [
          _Offer(
            logo: const AppLogo(
                name: 'Sony LIV',
                url:
                    'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/dishsmartottapps/sonyliv.webp',
                size: 42),
            title: 'Sony LIV Premium',
            line: 'Shows & sports · ₹49/mo',
            action: 'Activate',
            onTap: () => _open(const AddOttScreen()),
          ),
          _Offer(
            logo: const ChannelLogo(
                name: 'Sony Ten 1',
                url:
                    'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/channels/sony-ten-1.webp',
                size: 42,
                ring: Colors.white),
            title: 'Asia Cup Final, live',
            line: 'Sony Ten 1 HD · ₹22/mo',
            action: 'Add',
            onTap: () => _open(const AddRemoveScreen()),
          ),
          if (!(s.connection?.isHd ?? false))
            _Offer(
            logo: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.hd_outlined, color: C.ink, size: 32)),
            title: 'Go HD on your TV',
            line: '14 channels in sharp HD',
            action: 'Upgrade',
            onTap: () => _open(const HdCheckScreen()),
          ),
        ]),
      );

  /// The tab bar. Like iOS's own, its labels grow only a little with large
  /// text (each tab is labelled for VoiceOver), so they stay one size.
  Widget _bottomNav() => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.25, child: _tabs());

  Widget _tabs() {
    const items = [
      (Icons.home_sharp, 'Home'),
      (Icons.live_tv_sharp, 'TV on the go'),
      (Icons.currency_rupee_sharp, 'Recharge'),
      (Icons.play_circle_outline_sharp, 'OTT'),
      (Icons.support_agent_sharp, 'Get help'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
      ),
      padding: EdgeInsets.only(
          top: 10, bottom: 10 + MediaQuery.paddingOf(context).bottom),
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
                  if (it.$2 == 'Recharge') return _open(const RechargeScreen());
                  if (it.$2 == 'Get help') return _open(const ContactSupportScreen());
                  if (it.$2 == 'OTT') return _open(const AddOttScreen());
                  comingSoon(context, it.$2);
                },
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      child: BrandShade(on: i == _nav, child: Icon(it.$1,
                          size: 22, color: i == _nav ? C.brand : C.muted)),
                    ),
                    const SizedBox(height: 4),
                    // One line, never broken mid-word: shrinks to fit instead.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: BrandShade(on: i == _nav, child: Text(it.$2,
                            maxLines: 1,
                            softWrap: false,
                            style: T.caption.copyWith(
                                fontSize: 11,
                                fontWeight: i == _nav
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == _nav ? C.brand : C.muted))),
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

enum _Tab { packs, recharge, account }

/// One action inside the services panel: a white line icon over its name,
/// with no box of its own. It tips back a little when pressed.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        label: label,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 18),
          child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            SizedBox(
                height: 30,
                child: Center(child: Icon(icon, size: 26, color: C.ink))),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: T.label.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: C.inkSoft)),
          ]),
        ),
      );
}

/// Three equal tabs on a quiet surface (no border). The chosen one sits on
/// a sliding orange block; labels stay on one line.
class _HomeTabs<V> extends StatelessWidget {
  const _HomeTabs(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    final i = options.indexWhere((o) => o.$1 == value);
    final n = options.length;
    return Container(
      height: 44,
      color: C.surface,
      padding: const EdgeInsets.all(4),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * i / (n - 1), 0),
          child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: G.brand))),
        ),
        Row(children: [
          for (final (j, o) in options.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: j == i,
                label: o.$2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (j == i) return;
                    HapticFeedback.selectionClick();
                    onChanged(o.$1);
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: T.label.copyWith(
                              fontSize: 13,
                              fontWeight:
                                  j == i ? FontWeight.w600 : FontWeight.w500,
                              color: j == i ? Colors.white : C.muted),
                          child: Text(o.$2, maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _Offer {
  const _Offer(
      {required this.logo,
      required this.title,
      required this.line,
      required this.action,
      required this.onTap});
  final Widget logo;
  final String title;
  final String line;
  final String action;
  final VoidCallback onTap;
}

/// Offers that take turns in one quiet dark card: every few seconds the next
/// one fades in. A small heading sits above it, with bars (only when there is
/// more than one offer) to show which is up; tap a bar to jump to it. Orange
/// is kept for the action button.
class _OfferCarousel extends StatefulWidget {
  const _OfferCarousel({required this.offers});
  final List<_Offer> offers;

  @override
  State<_OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends State<_OfferCarousel> {
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (widget.offers.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || MediaQuery.of(context).disableAnimations) return;
      setState(() => _page = (_page + 1) % widget.offers.length);
    });
  }

  void _go(int i) {
    setState(() => _page = i);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The list can shrink (Go HD leaves once the TV is on HD).
    if (_page >= widget.offers.length) _page = 0;
    final o = widget.offers[_page];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('Offers for you',
                style: T.section
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
        if (widget.offers.length > 1)
          for (var i = 0; i < widget.offers.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _go(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == _page ? 14 : 5,
                  height: 4,
                  decoration: BoxDecoration(gradient: i == _page ? G.brand : null, color: i == _page ? null : C.lineStrong),
                ),
              ),
            ),
      ]),
      const SizedBox(height: S.md),
      Container(
        color: C.surface,
        padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md),
        // Tall enough for both lines at the reader's text size.
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(44).clamp(44.0, 140.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position:
                      Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                          .animate(a),
                  child: child),
            ),
            child: Row(key: ValueKey(_page), children: [
              o.logo,
              const SizedBox(width: S.md),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(o.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.item.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: C.ink)),
                      const SizedBox(height: 2),
                      Text(o.line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              T.caption.copyWith(fontSize: 12, color: C.muted)),
                    ]),
              ),
              const SizedBox(width: S.sm),
              Material(
                type: MaterialType.transparency,
                child: Ink(
                  decoration: const BoxDecoration(gradient: G.brand),
                  child: InkWell(
                    onTap: o.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Text(o.action,
                          style: T.label.copyWith(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
