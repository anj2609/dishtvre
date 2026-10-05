// Explore packs (step 1 of 3): TV or TV + OTT, SD or HD, filters, and pack
// cards. Tap a card to choose it; Compare up to two against your pack.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../top_ups/top_ups_screen.dart';
import '../widgets/widgets.dart';
import 'compare_screen.dart';
import 'filters.dart';
import 'pack_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  PackType _type = PackType.tv;
  bool? _hd;
  PackFilter _filter = PackFilter.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final plan = context.read<PlanStore>();
      final c = context.read<AppStore>().connection;
      if (c != null) await plan.open(c);
      plan.loadPacks();
    });
  }

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  List<Pack> _inView(PlanStore p, bool hd) => p.packs.where((x) => x.type == _type && x.isHd == hd && !x.isCurrent).toList();

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final c = context.watch<AppStore>().connection;
    final hd = _hd ?? (c?.isHd ?? false);
    final base = _inView(plan, hd);
    final packs = _filter.apply(base);
    final languages = (plan.packs.expand((p) => p.languages).toSet().toList()..sort());

    // Badges across what's shown.
    final badges = <int, (String, Color, Color)>{};
    if (packs.length >= 3) {
      final cheapest = packs.reduce((a, b) => a.price <= b.price ? a : b);
      final most = packs.reduce((a, b) => a.channels >= b.channels ? a : b);
      final value = packs.reduce((a, b) => a.price / a.channels <= b.price / b.channels ? a : b);
      badges[value.id] = ('Best value', C.success, C.successSoft);
      badges.putIfAbsent(cheapest.id, () => ('Lowest price', C.warning, C.warningSoft));
      badges.putIfAbsent(most.id, () => ('Most channels', C.info, C.infoSoft));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Explore packs', subtitle: 'Step 1 of 3: Choose a pack'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: S.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: S.page),
                  child: Segmented<PackType>(
                    height: 40,
                    options: const [(PackType.tv, 'TV packs'), (PackType.ottTv, 'TV + OTT packs')],
                    value: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, 0),
                  child: Row(children: [
                    SizedBox(
                      width: 128,
                      child: Segmented<bool>(
                        height: 32,
                        options: const [(false, 'SD'), (true, 'HD')],
                        value: hd,
                        onChanged: (v) => setState(() => _hd = v),
                      ),
                    ),
                    const SizedBox(width: S.sm),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(fit: BoxFit.scaleDown, child: _filtersButton(plan, base, languages)),
                      ),
                    ),
                  ]),
                ),
                if (_filter.count > 0) _activeFilters(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, S.sm),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${packs.length} ${packs.length == 1 ? 'pack' : 'packs'}', style: T.label),
                    TextSpan(text: '  |  ${hd ? 'HD' : 'SD'}  |  Prices include GST', style: T.caption),
                  ])),
                ),
                if (hd && c != null && !c.isHd)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm),
                    child: Panel(
                      color: Colors.transparent,
                      borderColor: C.warning,
                      padding: const EdgeInsets.all(S.md),
                      child: Text('Your box is SD. HD packs need an HD box — you can still browse and compare.',
                          style: T.caption.copyWith(color: C.warning, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (plan.loadingPacks && plan.packs.isEmpty)
                  for (var i = 0; i < 3; i++) const Skeleton(height: 190)
                else if (packs.isEmpty)
                  EmptyNote(
                    title: 'No packs match',
                    body: 'Try removing a filter or switching SD / HD.',
                    action: _filter.count > 0 ? 'Clear filters' : null,
                    onAction: () => setState(() => _filter = PackFilter.none),
                  )
                else
                  for (final p in packs)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
                      child: _PackCard(
                        key: ValueKey('pack-${p.id}'),
                        pack: p,
                        channels: plan.channelsOf(p),
                        badge: badges[p.id],
                        current: plan.basePack?.price ?? 0,
                        chosen: plan.newBase?.id == p.id,
                        comparing: plan.isComparing(p),
                        onChoose: () => plan.choose(p),
                        onDetails: () => _go(PackDetailsScreen(pack: p)),
                        onCompare: () {
                          if (!plan.toggleCompare(p)) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('You can compare up to 3 packs — your pack plus 2. Remove one to add another.')));
                          }
                        },
                      ),
                    ),
              ],
            ),
          ),
          _footer(plan),
        ]),
      ),
    );
  }

  Widget _filtersButton(PlanStore plan, List<Pack> base, List<String> languages) {
    final n = _filter.count;
    // Outline only; turns coral when filters are on.
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(side: BorderSide(color: n > 0 ? C.brand : C.lineStrong, width: n > 0 ? 1.5 : 1)),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(),
        onTap: () async {
          final f = await showFilters(context, current: _filter, languages: languages, countFor: (d) => d.apply(base).length);
          if (f != null && mounted) setState(() => _filter = f);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune_sharp, size: 18, color: n > 0 ? C.brand : C.ink),
            const SizedBox(width: 6),
            Text(n > 0 ? 'Filters ($n)' : 'Filters', style: T.label.copyWith(color: n > 0 ? C.brand : C.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _activeFilters() {
    final f = _filter;
    final chips = <(String, PackFilter)>[
      if (f.sort != SortBy.recommended) (sortLabels[f.sort]!, f.copyWith(sort: SortBy.recommended)),
      for (final l in f.languages) (l, f.copyWith(languages: {...f.languages}..remove(l))),
      for (final g in f.genres) ('Has $g', f.copyWith(genres: {...f.genres}..remove(g))),
      if (f.price != PriceBand.any) (priceLabels[f.price]!, f.copyWith(price: PriceBand.any)),
    ];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, 0),
        children: [
          for (final (label, without) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(label, style: T.caption.copyWith(color: C.ink, fontWeight: FontWeight.w700)),
                onDeleted: () => setState(() => _filter = without),
                deleteIcon: const Icon(Icons.close_sharp, size: 16),
                backgroundColor: C.surface,
                side: const BorderSide(color: C.lineStrong),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _filter = PackFilter.none),
            child: Text('Clear all', style: T.label.copyWith(color: C.brandDeep)),
          ),
        ],
      ),
    );
  }

  Widget _footer(PlanStore plan) {
    final chosen = plan.newBase;
    final comparing = plan.compare.isNotEmpty;
    final canCompare = plan.compare.isNotEmpty;
    void compare() => _go(const CompareScreen());
    void next() => _go(const TopUpsScreen(step: 'Step 2 of 3: Optional extras'));
    Widget main;
    if (chosen == null && comparing) {
      main = PrimaryButton(label: 'Compare packs', subtitle: 'Your pack + ${plan.compare.length}', onTap: canCompare ? compare : null);
    } else if (chosen != null) {
      main = PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_sharp, onTap: next);
    } else {
      main = const PrimaryButton(label: 'Choose a pack to continue');
    }
    return BottomBar(
      child: Row(children: [
        if (chosen != null && comparing) ...[
          SizedBox(width: 128, child: SecondaryButton(label: 'Compare', onTap: compare)),
          const SizedBox(width: S.md),
        ],
        Expanded(
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey('${chosen?.id}-$comparing'), child: main))),
      ]),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    super.key,
    required this.pack,
    required this.badge,
    required this.current,
    required this.chosen,
    required this.comparing,
    required this.onChoose,
    required this.onDetails,
    required this.onCompare,
    required this.channels,
  });

  final Pack pack;
  final Future<List<Channel>> channels;
  final (String, Color, Color)? badge;
  final double current;
  final bool chosen;
  final bool comparing;
  final VoidCallback onChoose;
  final VoidCallback onDetails;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final p = pack;
    final d = current > 0 ? p.price - current : null;
    final flag = chosen ? ('CHOSEN', C.brand) : (badge == null ? null : (badge!.$1.toUpperCase(), C.muted));
    // Compact and flat: an outline, no fills.
    return Semantics(
      container: true,
      button: true,
      selected: chosen,
      label: '${p.name}, ${rupees(p.price)} a month${chosen ? ', chosen' : ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(border: Border.all(color: chosen ? C.brand : C.cardEdge, width: chosen ? 2 : 1)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onChoose,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (flag != null) Text(flag.$1, style: T.overline.copyWith(fontSize: 10, color: flag.$2)),
                        Text(p.name, style: T.item.copyWith(fontSize: 15.5, height: 1.25)),
                        Text(
                          '${p.channels} channels${p.hdChannels > 0 ? ' | ${p.hdChannels} HD' : ''} | ${p.languages.join(' | ')}',
                          style: T.caption.copyWith(fontSize: 12),
                        ),
                      ]),
                    ),
                    const SizedBox(width: S.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.32),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: rupees(p.price), style: T.price.copyWith(fontSize: 19)),
                            TextSpan(text: '/mo', style: T.caption.copyWith(fontSize: 11)),
                          ])),
                        ),
                        if (d != null)
                          Text(
                            d.abs() < 0.5 ? 'Same as yours' : '${rupees(d.abs())} ${d < 0 ? 'less' : 'more'}',
                            textAlign: TextAlign.end,
                            style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: d <= 0 ? C.success : C.warning),
                          ),
                      ]),
                    ),
                  ]),
                ),
                if (p.ottApps.isNotEmpty) ...[
                  const SizedBox(height: S.sm),
                  Row(children: [
                    for (final o in p.ottApps) ...[AppLogo(name: o, url: p.ottLogoUrls[o], size: 22), const SizedBox(width: 5)],
                    const SizedBox(width: 3),
                    Expanded(child: Text('Includes ${p.ottApps.join(' | ')}', style: T.caption.copyWith(fontSize: 12, color: C.inkSoft))),
                  ]),
                ],
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.only(right: 8), child: _LogoStrip(channels: channels, total: p.channels)),
                if (p.lockIn || p.ruleMessage != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.info_outline_sharp, size: 14, color: C.muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(p.ruleMessage ?? 'A lock-in period applies.', style: T.caption.copyWith(fontSize: 11.5))),
                  ]),
                ],
                // Plain text actions: no boxes. Wraps on narrow screens with big text.
                Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Semantics(
                    container: true,
                    button: true,
                    selected: comparing,
                    label: comparing ? 'Comparing ${p.name}' : 'Compare ${p.name}',
                    child: ExcludeSemantics(
                      child: TextButton.icon(
                        onPressed: onCompare,
                        style: TextButton.styleFrom(
                          foregroundColor: comparing ? C.brand : C.ink,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          shape: const RoundedRectangleBorder(),
                        ),
                        icon: Icon(comparing ? Icons.check_sharp : Icons.compare_arrows_sharp, size: 17),
                        label: Text(comparing ? 'Comparing' : 'Compare', style: T.label.copyWith(color: comparing ? C.brand : C.ink)),
                      ),
                    ),
                  ),
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Details of ${p.name}',
                    child: ExcludeSemantics(
                      child: TextButton(
                        onPressed: onDetails,
                        style: TextButton.styleFrom(
                          foregroundColor: C.brand,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Details', style: T.label.copyWith(color: C.brand)),
                          const Icon(Icons.chevron_right_sharp, size: 18, color: C.brand),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of overlapping channel logos with a count of the rest. Picks one
/// channel per genre first so the row shows what kind of pack it is.
class _LogoStrip extends StatelessWidget {
  const _LogoStrip({required this.channels, required this.total});

  final Future<List<Channel>> channels;
  final int total;

  static const _size = 30.0;
  static const _step = 22.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      child: FutureBuilder<List<Channel>>(
        future: channels,
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const SizedBox.shrink();
          final picks = <Channel>[];
          final seen = <String>{};
          for (final pass in [0, 1]) {
            final genres = <String>{};
            for (final c in all) {
              if (c.logoUrl == null || seen.contains(c.logoUrl)) continue;
              if (pass == 0 && !genres.add(c.genre)) continue;
              seen.add(c.logoUrl!);
              picks.add(c);
            }
          }
          return LayoutBuilder(builder: (context, box) {
            const moreWidth = 96.0;
            final fit = ((box.maxWidth - moreWidth - _size) / _step).floor() + 1;
            final shown = picks.take(fit.clamp(1, 7)).toList();
            final rest = total - shown.length;
            return Row(children: [
              SizedBox(
                width: _size + _step * (shown.length - 1),
                height: _size,
                child: Stack(children: [
                  for (final (i, c) in shown.indexed) Positioned(left: i * _step, child: ChannelLogo(name: c.name, url: c.logoUrl, size: _size)),
                ]),
              ),
              if (rest > 0) ...[
                const SizedBox(width: S.sm),
                Flexible(
                  child: Text('+$rest more', maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: T.label.copyWith(color: C.muted)),
                ),
              ],
            ]);
          });
        },
      ),
    );
  }
}
