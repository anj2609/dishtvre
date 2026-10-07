// Add OTT: OTT apps for the chosen TV, one by one or as a bundle that costs
// less. A rotating hero of shows on VZY sits on top (where the apps are
// watched). SD or HD changes the prices. Bundles come first as swipeable
// cards; apps follow, filtered by category or search. Picked apps go onto
// the plan as add-ons, so "Review" leads to the same review and
// confirmation as any other plan change. Apps already on the plan show as
// active; apps inside a picked bundle show as included.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../checkout/review_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import '../checkout/new_bill.dart';
import '../checkout/plan_exit_guard.dart';

const _logoBase = 'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/dishsmartottapps/';

const _cats = ['All', 'Entertainment', 'Movies', 'Regional', 'Sports & Docs', 'Free'];

/// One OTT app: plan id, name, logo file, monthly price in SD and HD, its
/// category, and words to search by.
class _App {
  const _App(this.id, this.name, this.logo, this.sd, this.hd, this.cat, this.tags);
  final int id;
  final String name;
  final String logo;
  final double sd;
  final double hd;
  final String cat;
  final String tags;

  String get url => '$_logoBase$logo.webp';
  double price(bool hdOn) => hdOn ? hd : sd;
  bool get free => sd == 0;
  bool inCat(String c) => c == 'All' || (c == 'Free' ? free : cat == c);
}

const _apps = [
  _App(7102, 'SonyLIV', 'sonyliv', 29, 49, 'Entertainment', 'sony shows sports cricket'),
  _App(7103, 'ZEE5 Premium', 'zee5', 49, 69, 'Entertainment', 'zee hindi shows'),
  _App(7104, 'JioHotstar', 'jiohotstar', 49, 79, 'Entertainment', 'hotstar disney star cricket'),
  _App(7101, 'Prime Video Lite', 'prime-video', 0, 0, 'Movies', 'amazon prime'),
  _App(7105, 'Watcho Exclusive', 'watcho-exclusives', 49, 49, 'Entertainment', 'originals dishtv'),
  _App(7110, 'Lionsgate Play', 'lionsgate-play', 49, 69, 'Movies', 'hollywood english'),
  _App(7106, 'hoichoi', 'hoichoi', 39, 49, 'Regional', 'bangla bengali'),
  _App(7108, 'FanCode', 'fancode', 25, 25, 'Sports & Docs', 'cricket football live sports'),
  _App(7107, 'Sun NXT', 'sun-nxt', 50, 65, 'Regional', 'tamil telugu south'),
  _App(7109, 'Discovery+', 'discovery', 25, 35, 'Sports & Docs', 'documentary science'),
  _App(7111, 'Hungama', 'hungama', 19, 29, 'Entertainment', 'music songs'),
  _App(7112, 'ShemarooMe', 'shemaroo-me', 19, 29, 'Movies', 'bollywood classic gujarati'),
  _App(7113, 'ManoramaMAX', 'manorama-max', 25, 35, 'Regional', 'malayalam'),
  _App(7114, 'Chaupal', 'chaupal', 19, 29, 'Regional', 'punjabi haryanvi bhojpuri'),
  _App(7115, 'STAGE', 'stage', 29, 39, 'Regional', 'haryanvi rajasthani'),
  _App(7116, 'Ultra Jhakaas', 'ultra-jhakaas', 19, 29, 'Regional', 'marathi'),
  _App(7117, 'Tarang Plus', 'tarang-plus', 15, 25, 'Regional', 'odia'),
  _App(7118, 'Aao NXT', 'aaonxt', 15, 25, 'Regional', 'bhojpuri'),
  _App(7119, 'NammaFlix', 'nammaflix', 19, 29, 'Regional', 'kannada'),
  _App(7120, 'Distro TV', 'distro-tv', 0, 0, 'Entertainment', 'live tv free'),
];

_App _app(String logo) => _apps.firstWhere((a) => a.logo == logo);

class _Bundle {
  const _Bundle(this.id, this.name, this.logos, this.sd, this.hd);
  final int id;
  final String name;
  final List<String> logos;
  final double sd;
  final double hd;

  List<_App> get apps => [for (final l in logos) _app(l)];
  double price(bool hdOn) => hdOn ? hd : sd;

  /// What the same apps cost one by one.
  double separately(bool hdOn) => apps.fold(0.0, (a, x) => a + x.price(hdOn));
}

const _bundles = [
  _Bundle(7201, 'Entertainment Bundle', ['sonyliv', 'zee5', 'lionsgate-play', 'hoichoi'], 49, 79),
  _Bundle(7202, 'Regional Bundle', ['sun-nxt', 'hoichoi', 'manorama-max', 'chaupal', 'stage', 'nammaflix'], 69, 99),
  _Bundle(7203, 'Sports & Docs Bundle', ['fancode', 'discovery', 'sonyliv'], 45, 65),
];

/// How many apps "All" shows before "View all".
const _firstApps = 8;

class AddOttScreen extends StatefulWidget {
  const AddOttScreen({super.key});

  @override
  State<AddOttScreen> createState() => _AddOttScreenState();
}

class _AddOttScreenState extends State<AddOttScreen> {
  bool _hd = false;
  bool _all = false;
  String _cat = 'All';
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Work on the TV picked across the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPlan());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openPlan() {
    final c = context.read<AppStore>().connection;
    final plan = context.read<PlanStore>();
    if (c != null && plan.connection?.vc != c.vc) plan.open(c);
  }

  Future<void> _pickTv(PlanStore plan) async {
    final picked = plan.added.where((i) => i.group == 'OTT').length;
    final vc = await showSwitchTvSheet(context, title: 'Add OTT to which TV?', subtitle: 'OTT apps are added to one connection at a time.');
    if (vc == null || !mounted) return;
    if (vc == plan.connection?.vc) return;
    if (picked > 0) {
      final ok = await showSheet<bool>(
        context,
        title: 'Switch TV?',
        subtitle: 'The $picked ${picked == 1 ? 'app' : 'apps'} you picked are for this TV and will be cleared.',
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrimaryButton(label: 'Switch TV', onTap: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: S.sm),
            SecondaryButton(label: 'Stay on this TV', onTap: () => Navigator.of(ctx).pop(false)),
          ]),
        ),
      );
      if (ok != true || !mounted) return;
    }
    context.read<AppStore>().selectVc(vc);
    _openPlan();
  }

  /// A plan item for an app or bundle at the chosen quality.
  PlanItem _item(int id, String name, double price, String? logo) => PlanItem(
        id: id + (_hd ? 1000 : 0),
        name: _hd ? '$name HD' : name,
        kind: ItemKind.addOn,
        group: 'OTT',
        price: price,
        channels: 0,
        isHd: _hd,
        broadcaster: 'OTT',
        logoUrl: logo,
      );

  /// Picked here: the add-on for this app or bundle, in either quality.
  PlanItem? _pickedOf(PlanStore plan, int id) => plan.added.where((i) => i.id == id || i.id == id + 1000).firstOrNull;

  /// On the plan already (matched by logo, as plan names differ a little),
  /// and not being replaced by a bundle.
  bool _active(PlanStore plan, _App a) => plan.items.any((i) => i.group == 'OTT' && i.logoUrl == a.url && !plan.isRemoved(i));

  /// Apps in [b] this TV already pays for separately. A bundle replaces
  /// them, so they aren't paid for twice.
  List<PlanItem> _alreadyHave(PlanStore plan, _Bundle b) =>
      plan.items.where((i) => i.group == 'OTT' && i.removable && b.apps.any((a) => a.url == i.logoUrl)).toList();

  _Bundle? _bundleIn(PlanStore plan) => _bundles.where((b) => _pickedOf(plan, b.id) != null).firstOrNull;

  void _toggleApp(PlanStore plan, _App a) {
    HapticFeedback.selectionClick();
    final p = _pickedOf(plan, a.id);
    if (p != null) {
      plan.undoAdd(p);
    } else {
      plan.add(_item(a.id, a.name, a.price(_hd), a.url));
    }
  }

  void _toggleBundle(PlanStore plan, _Bundle b) {
    HapticFeedback.selectionClick();
    final current = _bundleIn(plan);
    if (current != null) {
      plan.undoAdd(_pickedOf(plan, current.id)!);
      // Apps the old bundle replaced go back on the plan.
      for (final i in _alreadyHave(plan, current)) {
        if (plan.isRemoved(i)) plan.toggleRemove(i);
      }
    }
    if (current?.id == b.id) return;
    plan.add(_item(b.id, b.name, b.price(_hd), b.apps.first.url));
    // Apps picked one by one that the bundle already has come off, and so do
    // ones already on the plan: the bundle replaces them.
    final dropped = <String>[];
    for (final a in b.apps) {
      final p = _pickedOf(plan, a.id);
      if (p != null) {
        plan.undoAdd(p);
        dropped.add(a.name);
      }
    }
    for (final i in _alreadyHave(plan, b)) {
      if (!plan.isRemoved(i)) plan.toggleRemove(i);
      dropped.add(i.name);
    }
    if (dropped.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                '${dropped.join(', ')} ${dropped.length == 1 ? 'is' : 'are'} in the bundle, so ${dropped.length == 1 ? 'it comes' : 'they come'} off separately. You won\'t pay twice.')));
    }
  }

  /// SD ↔ HD: anything picked moves to the new quality.
  void _setHd(PlanStore plan, bool hd) {
    if (hd == _hd) return;
    final apps = _apps.where((a) => _pickedOf(plan, a.id) != null).toList();
    final bundle = _bundleIn(plan);
    for (final i in plan.added.where((i) => i.group == 'OTT' && i.id >= 7101).toList()) {
      plan.undoAdd(i);
    }
    setState(() => _hd = hd);
    for (final a in apps) {
      plan.add(_item(a.id, a.name, a.price(_hd), a.url));
    }
    if (bundle != null) plan.add(_item(bundle.id, bundle.name, bundle.price(_hd), bundle.apps.first.url));
  }

  /// What's in a bundle, with the option to pick it.
  void _bundleInfo(PlanStore plan, _Bundle b) => showSheet<void>(
        context,
        title: b.name,
        subtitle: '${b.apps.length} OTT apps for ${rupees(b.price(_hd))} a month in ${_hd ? 'HD' : 'SD'}',
        builder: (ctx) {
          final picked = _bundleIn(plan)?.id == b.id;
          return Padding(
            padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final a in b.apps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    AppLogo(name: a.name, url: a.url, size: 40),
                    const SizedBox(width: S.md),
                    Expanded(child: Text(a.name, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
                    Text('${rupees(a.price(_hd))}/mo',
                        style: T.caption.copyWith(fontSize: 12.5, color: C.muted, decoration: TextDecoration.lineThrough, decorationColor: C.muted)),
                  ]),
                ),
              const SizedBox(height: S.md),
              Text.rich(TextSpan(style: T.body.copyWith(fontSize: 13.5), children: [
                TextSpan(text: 'Separately ${rupees(b.separately(_hd))}/mo. '),
                TextSpan(
                    text: 'You save ${rupees(b.separately(_hd) - b.price(_hd))} every month.',
                    style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.success)),
              ])),
              if (_alreadyHave(plan, b).isNotEmpty) ...[
                const SizedBox(height: S.sm),
                Text('Replaces ${_alreadyHave(plan, b).map((i) => i.name).join(' and ')}, which you have now, so you won\'t pay for it twice.',
                    style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
              ],
              const SizedBox(height: S.lg),
              PrimaryButton(
                label: picked ? 'Remove bundle' : 'Add bundle · ${rupees(b.price(_hd))}/mo',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _toggleBundle(plan, b);
                },
              ),
            ]),
          );
        },
      );

  void _vzy() => showSheet<void>(
        context,
        title: 'Watch on VZY',
        subtitle: 'Your OTT apps and live TV in one app, on your phone, tablet or smart TV.',
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (icon, text) in const [
              (Icons.login_sharp, 'Sign in with your registered mobile number'),
              (Icons.apps_sharp, 'Every OTT app you add here shows up in VZY'),
              (Icons.live_tv_sharp, '300+ live TV channels, 24 OTT apps'),
              (Icons.devices_sharp, 'Watch on up to 4 screens'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  BrandShade(child: Icon(icon, size: 21, color: C.brand)),
                  const SizedBox(width: S.md),
                  Expanded(child: Text(text, style: T.body.copyWith(fontSize: 14))),
                ]),
              ),
            const SizedBox(height: S.lg),
            PrimaryButton(
              label: 'Open VZY',
              icon: Icons.open_in_new_sharp,
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Opening VZY…')));
              },
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final plan = context.watch<PlanStore>();
    final c = app.connection;
    final bundle = _bundleIn(plan);
    final q = _query.trim().toLowerCase();
    bool hit(_App a) => q.isEmpty || a.name.toLowerCase().contains(q) || a.tags.contains(q) || a.cat.toLowerCase().contains(q);
    final matches = _apps.where((a) => a.inCat(_cat) && hit(a)).toList();
    final capped = _cat == 'All' && q.isEmpty && !_all && matches.length > _firstApps;
    final shown = capped ? matches.take(_firstApps).toList() : matches;
    final bundles = _bundles.where((b) => q.isEmpty || b.name.toLowerCase().contains(q) || b.apps.any(hit)).toList();
    final picked = plan.added.where((i) => i.group == 'OTT').toList();
    final pickedCost = picked.fold(0.0, (a, i) => a + i.price);
    return PlanExitGuard(
        child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Add OTT'),
          if (c != null)
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
                child: InkWell(
                  onTap: app.connections.length > 1 ? () => _pickTv(plan) : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(c.label, style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text('  ·  VC ', style: T.caption.copyWith(color: C.muted)),
                      Text(c.vcPretty, style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      if (app.connections.length > 1) ...[const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_sharp, color: C.inkSoft, size: 20)],
                    ]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: S.xxl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: S.page), child: Reveal(child: _VzyHero(onTap: _vzy))),
                const SizedBox(height: S.xl),
                // Picture quality, then search.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.page),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Picture quality', style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(_hd ? 'Prices for HD set-top boxes' : 'Prices for SD set-top boxes', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                        ]),
                      ),
                      SizedBox(
                        width: 116,
                        child: Segmented<bool>(options: const [(false, 'SD'), (true, 'HD')], value: _hd, height: 36, onChanged: (v) => _setHd(plan, v)),
                      ),
                    ]),
                    const SizedBox(height: S.lg),
                    SearchBox(hint: 'Search apps, languages or sports', controller: _search, onChanged: (v) => setState(() => _query = v)),
                  ]),
                ),
                // Bundles: swipeable cards.
                if (bundles.isNotEmpty) ...[
                  const SizedBox(height: S.xxl),
                  _sectionTitle('Save with bundles', 'More apps for less'),
                  const SizedBox(height: S.md),
                  SizedBox(
                    height: 178,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: S.page),
                      itemCount: bundles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: S.md),
                      itemBuilder: (_, i) => _BundleCard(
                        bundle: bundles[i],
                        hd: _hd,
                        picked: bundle?.id == bundles[i].id,
                        onTap: () => _bundleInfo(plan, bundles[i]),
                        onPick: () => _toggleBundle(plan, bundles[i]),
                      ),
                    ),
                  ),
                ],
                // Apps one by one.
                const SizedBox(height: S.xxl),
                _sectionTitle('OTT apps', q.isEmpty ? '${_apps.length} apps' : '${matches.length} found'),
                const SizedBox(height: S.md),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: S.page),
                    itemCount: _cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: S.sm),
                    itemBuilder: (_, i) => Pick(
                      label: _cats[i],
                      selected: _cat == _cats[i],
                      onTap: () => setState(() {
                        _cat = _cats[i];
                        _all = false;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: S.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.page),
                  child: matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: S.lg),
                          child: Column(children: [
                            Icon(Icons.search_off_sharp, size: 30, color: C.faint),
                            const SizedBox(height: S.sm),
                            Text(q.isEmpty ? 'No apps here yet.' : 'No app matches "${_query.trim()}"${_cat == 'All' ? '' : ' in $_cat'}.',
                                textAlign: TextAlign.center, style: T.body.copyWith(fontSize: 13.5, color: C.muted)),
                            if (_cat != 'All')
                              TextButton(
                                onPressed: () => setState(() => _cat = 'All'),
                                child: BrandShade(
                                    child: Text('Search all apps', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand))),
                              ),
                          ]),
                        )
                      : _Grid(children: [
                          for (final a in shown)
                            _AppTile(
                              app: a,
                              hd: _hd,
                              state: _active(plan, a)
                                  ? _Tile.active
                                  : bundle != null && bundle.logos.contains(a.logo)
                                      ? _Tile.inBundle
                                      : _pickedOf(plan, a.id) != null
                                          ? _Tile.picked
                                          : _Tile.open,
                              onTap: () => _toggleApp(plan, a),
                            ),
                        ]),
                ),
                if (capped || (_all && _cat == 'All' && q.isEmpty))
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _all = !_all),
                      child: BrandShade(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_all ? 'Show fewer' : 'View all ${_apps.length} apps',
                              style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.brand)),
                          Icon(_all ? Icons.keyboard_arrow_up_sharp : Icons.keyboard_arrow_down_sharp, size: 20, color: C.brand),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // What's picked, and on to review. Slides up once something is.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, a) => SizeTransition(
              sizeFactor: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: a, child: child),
            ),
            child: picked.isEmpty
                ? SizedBox(key: const ValueKey('none'), width: double.infinity, height: MediaQuery.paddingOf(context).bottom)
                : BottomBar(
                    key: const ValueKey('bar'),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('${picked.length} ${picked.length == 1 ? 'item' : 'items'}  ·  +${rupees(pickedCost)}/mo',
                              style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(newBillLine(plan, suffix: '/mo'), style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                        ]),
                      ),
                      const SizedBox(width: S.md),
                      SizedBox(
                        width: 140,
                        child: PrimaryButton(
                          label: 'Review',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
                        ),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    ));
  }

  Widget _sectionTitle(String title, String note) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: S.page),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(title, style: T.section.copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
          Text(note, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Hero

const _art = 'https://imagesv2.dsp1.ott.kaltura.com/Service.svc/GetImage/p/5093/entry_id';
const _shows = [
  ('The Outlaws', 'Action movie', '$_art/5d1b171103b945168da6912c0b70e006/version/1/width/960/height/540/quality/85'),
  ('Real Kashmir Football Club', 'Drama series', '$_art/4f79398d126243609c46e2da97b7bad0/version/75/width/960/height/540/quality/85'),
  ('The Seekers', 'Investigation series', '$_art/11b5a82b125b405e88234adbd080f49e/version/0/width/960/height/540/quality/85'),
  ('Modern Prem', 'Gujarati drama series', '$_art/6b5261d0c318436f80bb007a02f679dd/version/9/width/960/height/540/quality/85'),
];
const _vzyLogo = 'https://client.vivre.dish.watcho.com/assets/f180ee7e-5309-4901-a89f-7002e4f66b33/project-icon/0905bd78-20e1-496e-bdd6-e05866e5ff83.webp';

/// Shows streaming on VZY, one after another, behind the VZY logo and the
/// button: a poster that says what the apps are for, without a wall of text.
class _VzyHero extends StatefulWidget {
  const _VzyHero({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_VzyHero> createState() => _VzyHeroState();
}

class _VzyHeroState extends State<_VzyHero> {
  final _pages = PageController();
  Timer? _tick;
  int _at = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tick?.cancel();
    if (MediaQuery.of(context).disableAnimations) return;
    _tick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.animateToPage((_at + 1) % _shows.length, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          // The artwork, swipeable.
          PageView.builder(
            controller: _pages,
            itemCount: _shows.length,
            onPageChanged: (i) => setState(() => _at = i),
            itemBuilder: (_, i) => Semantics(
              image: true,
              label: '${_shows[i].$1}, ${_shows[i].$2}, on VZY',
              child: Image.network(
                _shows[i].$3,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: G.brand)),
                frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                  opacity: sync || frame != null ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                ),
              ),
            ),
          ),
          // Dark at the top and bottom so the logo and button read.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.3, 0.8, 1],
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0x66000000)],
                ),
              ),
            ),
          ),
          // VZY logo.
          Positioned(
            left: S.lg,
            top: S.md,
            child: IgnorePointer(
              child: Row(children: [
                Image.network(_vzyLogo,
                    height: 26,
                    errorBuilder: (_, __, ___) => Text('VZY', style: T.title.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFDC312)))),
                const SizedBox(width: S.sm),
                Text('Streaming now', style: T.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xE6FFFFFF))),
              ]),
            ),
          ),
          // Which slide this is. The artwork carries its own title, so
          // nothing else sits on it.
          Positioned(
            left: 0,
            right: 0,
            bottom: S.md,
            child: IgnorePointer(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _shows.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _at ? 16 : 5,
                    height: 4,
                    color: i == _at ? Colors.white : const Color(0x80FFFFFF),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
    // The artwork in full, then the way into VZY on a dark strip below it.
    return Container(
      color: const Color(0xFF0B0B10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        art,
        Padding(
          padding: const EdgeInsets.fromLTRB(S.lg, S.md, S.lg, S.lg),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your OTT apps, all in one app', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('300+ live channels  ·  24 apps', style: T.caption.copyWith(fontSize: 11.5, color: const Color(0xB3FFFFFF))),
              ]),
            ),
            const SizedBox(width: S.md),
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Open VZY', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF14141B))),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_sharp, size: 17, color: Color(0xFF14141B)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Bundles

/// A bundle as a card: its app icons overlapping, name, what it saves, the
/// price, and Add. Tapping the card shows what's inside.
class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle, required this.hd, required this.picked, required this.onTap, required this.onPick});
  final _Bundle bundle;
  final bool hd;
  final bool picked;
  final VoidCallback onTap;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final b = bundle;
    final save = b.separately(hd) - b.price(hd);
    const icon = 38.0;
    const step = 28.0;
    final show = b.apps.take(4).toList();
    final extra = b.apps.length - show.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 252,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(gradient: picked ? G.brandInk : null, color: picked ? null : C.surface),
      child: Material(
        color: C.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(S.md + 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Overlapping icons.
              SizedBox(
                height: icon,
                child: Stack(children: [
                  for (final (i, a) in show.indexed)
                    Positioned(
                      left: i * step,
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: C.surface, width: 2)),
                        child: AppLogo(name: a.name, url: a.url, size: icon - 4),
                      ),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: show.length * step,
                      child: Container(
                        width: icon,
                        height: icon,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.raised, border: Border.all(color: C.surface, width: 2)),
                        child: Text('+$extra', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: S.md),
              Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(style: T.caption.copyWith(fontSize: 12, color: C.muted), children: [
                  TextSpan(text: '${b.apps.length} apps'),
                  if (save > 0) ...[
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: 'Save ${rupees(save)}/mo', style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: C.success)),
                  ],
                ]),
              ),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: rupees(b.price(hd)), style: T.price.copyWith(fontSize: 19)),
                    TextSpan(text: '/mo', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  ])),
                ),
                // Add / Added.
                Semantics(
                  button: true,
                  selected: picked,
                  label: '${picked ? 'Remove' : 'Add'} ${b.name}',
                  child: InkWell(
                    onTap: onPick,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: picked ? G.brand : null,
                        border: picked ? null : Border.all(color: C.brand, width: 1.2),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (picked) ...[const Icon(Icons.check_sharp, size: 15, color: Colors.white), const SizedBox(width: 4)],
                        BrandShade(
                          on: !picked,
                          child: Text(picked ? 'Added' : 'Add',
                              style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: picked ? Colors.white : C.brand)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apps

/// Four to a row.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const cols = 4;
        const gap = S.sm;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: S.lg, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

enum _Tile { open, picked, active, inBundle }

/// An app: icon, name and price. Picked, the icon gets the gradient frame
/// and a tick; active or in a bundle, it says so and can't be picked.
class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.hd, required this.state, required this.onTap});
  final _App app;
  final bool hd;
  final _Tile state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = app.price(hd);
    final (sub, tone) = switch (state) {
      _Tile.active => ('Active', C.success),
      _Tile.inBundle => ('In bundle', C.inkSoft),
      _ => (price == 0 ? 'Free' : '${rupees(price)}/mo', state == _Tile.picked ? C.ink : C.muted),
    };
    final picked = state == _Tile.picked;
    final can = state == _Tile.open || picked;
    return Semantics(
      button: can,
      selected: picked,
      label: '${app.name}, $sub',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: can ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(clipBehavior: Clip.none, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.all(picked ? 2.5 : 0),
                    decoration: BoxDecoration(gradient: picked ? G.brandInk : null),
                    child: Opacity(opacity: state == _Tile.inBundle ? 0.45 : 1, child: AppLogo(name: app.name, url: app.url, size: picked ? 55 : 60)),
                  ),
                  if (picked || state == _Tile.active)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: picked ? G.brand : null,
                          color: picked ? null : C.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.bg, width: 2),
                        ),
                        child: const Icon(Icons.check_sharp, size: 13, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(sub,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: T.caption.copyWith(fontSize: 11.5, fontWeight: state == _Tile.open ? FontWeight.w500 : FontWeight.w700, color: tone)),
            ]),
          ),
        ),
      ),
    );
  }
}
