// Add / Remove: one place to add channels and take things off your plan.
//
// Add: SD / HD, filters and search, then channels as logo tiles grouped
// into Trending near you, each genre, bouquets and add-ons. Tap a tile to
// add it. Remove: your plan grouped like a bill (base pack, single
// channels, add-ons, OTT, bouquets, services), each opening to its items.
// Changes collect at the bottom with the new bill and Review.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/change_pack_screen.dart';
import '../change_pack/plan_screen.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../checkout/review_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'channel_filters.dart';

class AddRemoveScreen extends StatefulWidget {
  const AddRemoveScreen({super.key});

  @override
  State<AddRemoveScreen> createState() => _AddRemoveScreenState();
}

class _AddRemoveScreenState extends State<AddRemoveScreen> {
  static const _genreOrder = ['Entertainment', 'Movies', 'Sports', 'News', 'Kids', 'Infotainment', 'Music', 'Devotional'];

  bool _remove = false;
  bool _pinned = true;
  late ChannelFilter _f = ChannelFilter(hd: context.read<AppStore>().connection?.isHd ?? false);
  String _q = '';
  final _search = TextEditingController();
  final Set<String> _collapsed = {};
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final plan = context.read<PlanStore>();
    final c = context.read<AppStore>().connection;
    if (c != null) await plan.open(c);
    for (final k in const [ItemKind.alaCarte, ItemKind.bouquet, ItemKind.addOn]) {
      plan.loadCatalog(k);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _switchTv() async {
    final vc = await showSwitchTvSheet(context);
    if (vc == null || !mounted) return;
    final app = context.read<AppStore>()..selectVc(vc);
    final c = app.connection;
    if (c != null) await context.read<PlanStore>().open(c);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final plan = context.watch<PlanStore>();
    final c = app.connection;
    // The TV row and Add / Remove switch stay pinned when there's room; on
    // short screens or with large text they scroll with the list instead.
    final mq = MediaQuery.of(context);
    final pin = mq.size.height >= 600 && mq.textScaler.scale(10) <= 13;
    _pinned = pin;
    final top = <Widget>[
      if (c != null) _tvRow(c, app.connections.length > 1),
      Padding(
        padding: EdgeInsets.fromLTRB(pin ? S.page : 0, S.sm, pin ? S.page : 0, 0),
        child: Segmented<bool>(
          height: 42,
          options: const [(false, 'Add'), (true, 'Remove')],
          value: _remove,
          onChanged: (v) => setState(() => _remove = v),
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Add / Remove'),
          if (pin) ...top,
          Expanded(child: _remove ? _removeList(plan, pin ? const [] : top) : _addList(plan, pin ? const [] : top)),
          if (plan.hasChanges) _footer(plan),
        ]),
      ),
    );
  }

  // "Bedroom | VC 0102 7734 590 ⌄", right-aligned; opens the TV picker.
  Widget _tvRow(Connection c, bool canSwitch) => Padding(
        padding: EdgeInsets.fromLTRB(_pinned ? S.page : 0, 0, _pinned ? S.page : 0, S.xs),
        child: Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            container: true,
            button: canSwitch,
            label: '${c.label}, VC ${c.vcPretty}${canSwitch ? '. Switch TV' : ''}',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: canSwitch ? _switchTv : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: c.label, style: T.label.copyWith(fontSize: 14)),
                          TextSpan(text: '  |  VC ', style: T.caption.copyWith(fontSize: 13)),
                          TextSpan(text: c.vcPretty, style: T.label.copyWith(fontSize: 14)),
                        ]),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    if (canSwitch) ...[const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_sharp, size: 20, color: C.ink)],
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  // ---------------------------------------------------------------- Add

  bool _matches(PlanItem i, {bool genreApplies = true}) {
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty && !i.name.toLowerCase().contains(q) && !i.broadcaster.toLowerCase().contains(q)) return false;
    if (_f.languages.isNotEmpty && !_f.languages.contains(i.language)) return false;
    if (_f.broadcasters.isNotEmpty && !_f.broadcasters.contains(i.broadcaster)) return false;
    if (genreApplies && _f.genres.isNotEmpty && !_f.genres.contains(i.genre)) return false;
    return true;
  }

  Widget _addList(PlanStore plan, List<Widget> leading) {
    final cat = plan.catalog(ItemKind.alaCarte);
    final bouquetsAll = plan.catalog(ItemKind.bouquet) ?? const <PlanItem>[];
    final addOnsAll = plan.catalog(ItemKind.addOn) ?? const <PlanItem>[];
    final channelsAll = cat ?? const <PlanItem>[];

    final channels = channelsAll.where((i) => i.isHd == _f.hd && _matches(i)).toList();
    // Bouquets and add-ons have no single genre, so a genre filter hides them.
    final bouquets = _f.genres.isEmpty ? bouquetsAll.where((i) => _matches(i, genreApplies: false)).toList() : const <PlanItem>[];
    final addOns = _f.genres.isEmpty ? addOnsAll.where((i) => _matches(i, genreApplies: false)).toList() : const <PlanItem>[];
    final trending = channels.where((i) => i.trend != null).take(4).toList();

    final byGenre = <String, List<PlanItem>>{};
    for (final i in channels) {
      byGenre.putIfAbsent(i.genre.isEmpty ? 'Other' : i.genre, () => []).add(i);
    }
    final genres = byGenre.keys.toList()
      ..sort((a, b) {
        int rank(String g) => _genreOrder.contains(g) ? _genreOrder.indexOf(g) : 99;
        return rank(a).compareTo(rank(b));
      });

    final allItems = [...channelsAll, ...bouquetsAll, ...addOnsAll];
    List<String> distinct(Iterable<String> v) => (v.where((x) => x.isNotEmpty).toSet().toList()..sort());
    final genreOptions = [
      ..._genreOrder.where((g) => channelsAll.any((i) => i.genre == g)),
      ...distinct(channelsAll.map((i) => i.genre)).where((g) => !_genreOrder.contains(g)),
    ];

    final nothing = cat != null && channels.isEmpty && bouquets.isEmpty && addOns.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.xxl),
      children: [
        ...leading,
        if (leading.isNotEmpty) const SizedBox(height: S.md),
        Row(children: [
          SizedBox(
            width: 140,
            child: Segmented<bool>(
              height: 34,
              options: const [(false, 'SD'), (true, 'HD')],
              value: _f.hd,
              onChanged: (v) => setState(() => _f = _f.copyWith(hd: v)),
            ),
          ),
          const Spacer(),
          _filterButton(genreOptions, distinct(allItems.map((i) => i.language)), distinct(allItems.map((i) => i.broadcaster))),
        ]),
        const SizedBox(height: S.md),
        SearchBox(hint: 'Search channels', controller: _search, onChanged: (v) => setState(() => _q = v)),
        if (_f.count > 0) ...[
          const SizedBox(height: S.sm),
          Row(children: [
            Expanded(child: Text('${_f.count} ${_f.count == 1 ? 'filter' : 'filters'} on', style: T.caption)),
            TextButton(
              onPressed: () => setState(() => _f = ChannelFilter(hd: _f.hd)),
              child: Text('Clear filters', style: T.label.copyWith(color: C.brand)),
            ),
          ]),
        ],
        if (cat == null)
          const Padding(padding: EdgeInsets.only(top: S.lg), child: Skeleton(height: 220))
        else if (nothing)
          EmptyNote(
            title: _q.trim().isNotEmpty ? 'No match for “$_q”' : 'Nothing matches these filters',
            body: 'Try another name, switch SD / HD, or clear the filters.',
            action: 'Clear search and filters',
            onAction: () => setState(() {
              _search.clear();
              _q = '';
              _f = ChannelFilter(hd: _f.hd);
            }),
          )
        else ...[
          if (trending.isNotEmpty) _section('Trending near you', badge: '${trending.length}', items: trending, plan: plan, showTrend: true),
          for (final g in genres) _section(g, sub: '${byGenre[g]!.length} ${byGenre[g]!.length == 1 ? 'channel' : 'channels'}', items: byGenre[g]!, plan: plan),
          if (bouquets.isNotEmpty)
            _section('Broadcaster Bouquets', sub: '${bouquets.length} ${bouquets.length == 1 ? 'bouquet' : 'bouquets'}', items: bouquets, plan: plan),
          if (addOns.isNotEmpty) _section('Add-ons', sub: '${addOns.length} ${addOns.length == 1 ? 'add-on' : 'add-ons'}', items: addOns, plan: plan),
        ],
      ],
    );
  }

  Widget _filterButton(List<String> genres, List<String> languages, List<String> broadcasters) {
    final n = _f.count;
    return Tooltip(
      message: n > 0 ? 'Filters, $n on' : 'Filters',
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(side: BorderSide(color: n > 0 ? C.brand : C.lineStrong, width: n > 0 ? 1.5 : 1)),
        child: InkWell(
          onTap: () async {
            final f = await showChannelFilters(context, current: _f, genres: genres, languages: languages, broadcasters: broadcasters);
            if (f != null && mounted) setState(() => _f = f);
          },
          child: SizedBox(
            width: 44,
            height: 40,
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.filter_alt_outlined, size: 22, color: n > 0 ? C.brand : C.ink),
              if (n > 0)
                Positioned(
                  top: 3,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: C.brand,
                    child: Text('$n', textScaler: TextScaler.noScaling, style: T.label.copyWith(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  // A collapsible group of tiles with its own heading.
  Widget _section(String title, {String? sub, String? badge, required List<PlanItem> items, required PlanStore plan, bool showTrend = false}) {
    final open = !_collapsed.contains(title);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: S.lg),
        child: Semantics(
          container: true,
          button: true,
          expanded: open,
          label: '$title${sub != null ? ', $sub' : ''}',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => setState(() => open ? _collapsed.add(title) : _collapsed.remove(title)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.sm),
                child: Row(children: [
                  Expanded(
                    child: Wrap(spacing: S.sm, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: title, style: T.section.copyWith(fontSize: 17)),
                        if (sub != null) TextSpan(text: '  $sub', style: T.caption.copyWith(fontSize: 13)),
                      ])),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: C.lineStrong)),
                          child: Text(badge, style: T.label.copyWith(fontSize: 12)),
                        ),
                    ]),
                  ),
                  Icon(open ? Icons.keyboard_arrow_up_sharp : Icons.keyboard_arrow_down_sharp, color: C.muted),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (open) ...[
        const SizedBox(height: S.sm),
        _TileGrid(items: items, plan: plan, showTrend: showTrend),
      ],
      const SizedBox(height: S.lg),
      const Divider(height: 1, color: C.line),
    ]);
  }

  // ------------------------------------------------------------- Remove

  Widget _removeList(PlanStore plan, List<Widget> leading) {
    if (plan.items.isEmpty) return ListView(children: const [SizedBox(height: S.lg), Skeleton(height: 72), Skeleton(height: 72), Skeleton(height: 72)]);
    final base = plan.basePack;
    String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
    final channels = plan.itemsOf(ItemKind.alaCarte);
    final addOns = plan.items.where((i) => i.kind == ItemKind.addOn && i.group == null).toList();
    final ott = plan.items.where((i) => i.group == 'OTT').toList();
    final bouquets = plan.itemsOf(ItemKind.bouquet);
    final services = plan.items.where((i) => i.group == 'Active Services').toList();
    final groups = <(String, String, String, List<PlanItem>)>[
      if (base != null) ('base', base.name, 'Base pack  |  ${n(base.channels, 'channel', 'channels')}', [base]),
      ('channels', 'Single Channels', n(channels.length, 'channel', 'channels'), channels),
      ('addons', 'Add-ons', n(addOns.length, 'add-on', 'add-ons'), addOns),
      ('ott', 'OTT', n(ott.length, 'app', 'apps'), ott),
      ('bouquets', 'Broadcaster Bouquets', n(bouquets.length, 'bouquet', 'bouquets'), bouquets),
      ('services', 'Active Services', n(services.length, 'service', 'services'), services),
    ].where((g) => g.$4.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xxl),
      children: [
        ...leading,
        for (final g in groups) _group(g.$1, g.$2, g.$3, g.$4, plan),
        const SizedBox(height: S.lg),
        Text('Prices include GST. Removals apply when you review and confirm.', style: T.caption),
      ],
    );
  }

  Widget _group(String key, String title, String sub, List<PlanItem> items, PlanStore plan) {
    final open = _open.contains(key);
    final total = items.fold(0.0, (a, i) => a + i.price);
    final removing = items.where(plan.isRemoved).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        container: true,
        button: true,
        expanded: open,
        label: '$title, $sub, ${rupees(total)} a month',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: S.lg),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: T.item.copyWith(fontSize: 16.5)),
                    const SizedBox(height: 2),
                    Text(sub, style: T.caption.copyWith(fontSize: 13)),
                    if (removing > 0) Text('$removing to remove', style: T.caption.copyWith(color: C.danger, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: S.md),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(rupees(total), style: T.item.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(open ? 'Hide details' : 'View details', style: T.label.copyWith(fontSize: 13, color: C.brand)),
                    Icon(open ? Icons.keyboard_arrow_up_sharp : Icons.keyboard_arrow_down_sharp, size: 18, color: C.brand),
                  ]),
                ]),
              ]),
            ),
          ),
        ),
      ),
      if (open) key == 'base' ? _baseDetails(plan) : Column(children: [for (final i in items) PlanItemRow(item: i, plan: plan)]),
      const Divider(height: 1, color: C.line),
    ]);
  }

  // The base pack can't be removed here: show what's in it and where to change it.
  Widget _baseDetails(PlanStore plan) => Padding(
        padding: const EdgeInsets.only(bottom: S.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FutureBuilder<List<Channel>>(
            future: plan.currentChannels(),
            builder: (context, snap) => LogoMarquee(logos: showcase(snap.data ?? const [], 14), size: 38, gap: 8),
          ),
          const SizedBox(height: S.md),
          Text('Your base pack can only be swapped for another pack, not removed.', style: T.caption),
          const SizedBox(height: S.sm),
          Wrap(spacing: S.sm, runSpacing: S.sm, children: [
            SecondaryButton(label: 'See all channels', onTap: () => _go(const PlanScreen())),
            SecondaryButton(label: 'Change pack', icon: Icons.layers_sharp, onTap: () => _go(const ChangePackScreen())),
          ]),
        ]),
      );

  // ------------------------------------------------------------- footer

  Widget _footer(PlanStore plan) => BottomBar(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${plan.changeCount} ${plan.changeCount == 1 ? 'change' : 'changes'} | New bill about', style: T.caption),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${rupees(plan.estimate)}/mo', style: T.price.copyWith(fontSize: 19)),
              ),
            ]),
          ),
          const SizedBox(width: S.md),
          Flexible(child: PrimaryButton(label: 'Review', onTap: () => _go(const ReviewScreen()))),
        ]),
      );
}

/// Channels (or bouquets / add-ons) as logo tiles: as many columns as fit,
/// up to four; names wrap between words only.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.items, required this.plan, this.showTrend = false});

  final List<PlanItem> items;
  final PlanStore plan;
  final bool showTrend;

  static const _gap = S.sm;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, box) {
      final cols = ((box.maxWidth + _gap) / (74 * scale + _gap)).floor().clamp(2, 4);
      final tileW = (box.maxWidth - _gap * (cols - 1)) / cols;
      final nameStyle = wordSafe(context, items.map((i) => i.name), T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25), tileW - 4);
      final rows = <Widget>[];
      for (var r = 0; r < items.length; r += cols) {
        final chunk = items.sublist(r, math.min(r + cols, items.length));
        rows.add(Padding(
          padding: EdgeInsets.only(bottom: r + cols < items.length ? S.md : 0),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: _gap),
                Expanded(child: j < chunk.length ? _Tile(item: chunk[j], plan: plan, style: nameStyle, showTrend: showTrend) : const SizedBox()),
              ],
            ]),
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.plan, required this.style, this.showTrend = false});

  final PlanItem item;
  final PlanStore plan;
  final TextStyle style;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final added = plan.isAdded(i);
    return Semantics(
      container: true,
      button: true,
      selected: added,
      label: '${i.name}, ${rupees(i.price)} a month${added ? ', added. Tap to undo' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            added ? plan.undoAdd(i) : plan.add(i);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              // Logo, with a check when added.
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: i.logoUrl != null
                        ? ChannelLogo(name: i.name, url: i.logoUrl, size: 60)
                        : Container(
                            decoration:
                                BoxDecoration(shape: BoxShape.circle, border: Border.all(color: i.isRecordingPlan ? C.danger : C.lineStrong, width: 1.5)),
                            child: Icon(i.isRecordingPlan ? Icons.fiber_manual_record_sharp : Icons.add_box_outlined,
                                color: i.isRecordingPlan ? C.danger : C.muted),
                          ),
                  ),
                  if (added)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: C.brand, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2)),
                        child: const Icon(Icons.check_sharp, size: 14, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: S.sm),
              Text(i.name, textAlign: TextAlign.center, style: style.copyWith(color: added ? C.brand : C.ink)),
              const SizedBox(height: 2),
              Text(rupees(i.price), textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 12)),
              if (showTrend && i.trend != null) ...[
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.trending_up_sharp, size: 13, color: C.brand)),
                    TextSpan(text: ' ${i.trend}'),
                  ]),
                  textAlign: TextAlign.center,
                  style: T.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.brand),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
