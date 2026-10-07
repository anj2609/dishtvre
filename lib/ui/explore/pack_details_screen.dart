// Pack details: price and quick facts, how it compares with your pack, and
// every channel — filter by genre or search.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/plan_store.dart';
import '../checkout/review_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'channel_diff_screen.dart';

class PackDetailsScreen extends StatefulWidget {
  const PackDetailsScreen({super.key, required this.pack});
  final Pack pack;

  @override
  State<PackDetailsScreen> createState() => _PackDetailsScreenState();
}

class _PackDetailsScreenState extends State<PackDetailsScreen> {
  late final PlanStore _plan = context.read<PlanStore>();
  late final Future<List<List<Channel>>> _lists = Future.wait([_plan.channelsOf(widget.pack), _plan.currentChannels()]);
  final _search = TextEditingController();
  String _q = '';
  String? _genre;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pack;
    final plan = context.watch<PlanStore>();
    final chosen = plan.newBase?.id == p.id;
    final current = plan.basePack?.price ?? 0;
    final d = current > 0 ? p.price - current : null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: p.name, subtitle: '${p.isHd ? 'HD' : 'SD'} pack | ${p.languages.join(' | ')}'),
          Expanded(
            child: FutureBuilder<List<List<Channel>>>(
              future: _lists,
              builder: (context, snap) {
                final all = snap.data?[0];
                final mine = snap.data?[1] ?? const <Channel>[];
                final mineKeys = mine.map((c) => c.key).toSet();
                final keys = all?.map((c) => c.key).toSet() ?? <String>{};
                final added = keys.difference(mineKeys).length;
                final kept = keys.intersection(mineKeys).length;
                final lost = mineKeys.difference(keys).length;
                final counts = <String, int>{};
                for (final c in all ?? const <Channel>[]) {
                  counts[c.genre] = (counts[c.genre] ?? 0) + 1;
                }
                final genres = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
                final q = _q.trim().toLowerCase();
                final shown =
                    (all ?? const <Channel>[]).where((c) => (_genre == null || c.genre == _genre) && (q.isEmpty || c.name.toLowerCase().contains(q))).toList();
                return CustomScrollView(slivers: [
                  // A glimpse of what's inside, gliding past.
                  if (all != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: S.md),
                        child: LogoMarquee(logos: showcase(all, 18), size: 46, speed: 18),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: S.page),
                      // Price card: a simple border, no fill.
                      child: Panel(
                        color: Colors.transparent,
                        borderColor: C.lineStrong,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Price and the difference tag share a line, and wrap on narrow screens or big text.
                          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: S.sm, runSpacing: 6, children: [
                            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(rupees(p.price), style: T.display.copyWith(color: C.ink)))),
                              Padding(padding: const EdgeInsets.only(left: 4, bottom: 3), child: Text('/month', style: T.caption.copyWith(color: _soft))),
                            ]),
                            if (d != null)
                              Text(
                                d.abs() < 0.5 ? 'Same as your pack' : '${rupees(d.abs())} ${d < 0 ? 'less' : 'more'} than your pack',
                                style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: d < 0 && d.abs() >= 0.5 ? C.success : C.ink),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${rupees(p.priceExTax)} + ${rupees(p.gst)} GST${p.ncf > 0 ? ' | NCF ${rupees(p.ncf)} extra' : ''}',
                              style: T.caption.copyWith(color: _soft)),
                          const SizedBox(height: S.lg),
                          Row(children: [
                            _fact('${p.channels}', 'Channels'),
                            _fact('${p.hdChannels}', 'HD'),
                            _fact('${p.ottApps.length}', 'OTT apps'),
                            _fact(p.ncf > 0 ? rupees(p.ncf) : '—', 'NCF'),
                          ]),
                          if (p.ottApps.isNotEmpty) ...[
                            const SizedBox(height: S.md),
                            Text('Includes ${p.ottApps.join(' | ')}', style: T.label.copyWith(color: C.ink)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  if (all != null && mine.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Compared with your pack', style: T.section),
                          Text('Tap to see the channels', style: T.caption),
                          const SizedBox(height: S.sm),
                          Row(children: [
                            _diff('$added', 'new', C.success, C.successSoft, () => _openDiff(all, mine, ChannelDiff.added)),
                            const SizedBox(width: S.sm),
                            _diff('$kept', 'you keep', C.info, C.infoSoft, () => _openDiff(all, mine, ChannelDiff.kept)),
                            const SizedBox(width: S.sm),
                            _diff('$lost', 'you lose', C.danger, C.dangerSoft, () => _openDiff(all, mine, ChannelDiff.lost)),
                          ]),
                        ]),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, S.md),
                      child: Row(children: [
                        Expanded(child: Text('Channels', style: T.section)),
                        if (all != null) Text('${shown.length} of ${all.length}', style: T.caption),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: S.page),
                      child: SearchBox(hint: 'Search channels in this pack', controller: _search, onChanged: (v) => setState(() => _q = v)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, 0),
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pick(label: 'All', selected: _genre == null, onTap: () => setState(() => _genre = null))),
                          for (final g in genres)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pick(label: '$g ${counts[g]}', selected: _genre == g, onTap: () => setState(() => _genre = _genre == g ? null : g)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (all == null)
                    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: S.lg), child: Skeleton(height: 260)))
                  else if (shown.isEmpty)
                    const SliverToBoxAdapter(child: EmptyNote(title: 'No channels match'))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.xxl),
                      sliver: DecoratedSliver(
                        decoration: BoxDecoration(border: Border.all(color: C.cardEdge)),
                        sliver: SliverList.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: C.line, indent: 64),
                          itemBuilder: (_, i) => _channel(shown[i], !mineKeys.contains(shown[i].key) && mine.isNotEmpty),
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
          // Choose goes straight to Review (then Confirm leads to the success screen).
          BottomBar(
            child: PrimaryButton(
              label: chosen ? 'Review' : 'Choose this pack for ${rupees(p.price)}/mo',
              onTap: () {
                if (!chosen) plan.choose(p);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen()));
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// Soft white text on the price card.
  static Color get _soft => C.muted;

  Widget _fact(String value, String label) => Expanded(
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.section.copyWith(fontSize: 18, color: C.ink))),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false, style: T.caption.copyWith(color: _soft))),
        ]),
      );

  void _openDiff(List<Channel> all, List<Channel> mine, ChannelDiff tab) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChannelDiffScreen(pack: widget.pack, packChannels: all, myChannels: mine, initial: tab),
      ));

  Widget _diff(String n, String label, Color fg, Color bg, VoidCallback onTap) => Expanded(
        child: Semantics(
          container: true,
          button: true,
          label: '$n channels $label, show list',
          // Solid fill in the tile's own colour.
          child: Material(
            color: fg,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: onTap,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: S.md, horizontal: S.sm),
                  child: Column(children: [
                    Text(n, style: T.title.copyWith(color: C.onInk)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(child: Text(label, textAlign: TextAlign.center, style: T.caption.copyWith(color: C.onInk, fontWeight: FontWeight.w800))),
                      Icon(Icons.chevron_right_sharp, size: 16, color: C.onInk),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _channel(Channel c, bool isNew) =>
      ChannelRow(channel: c, tags: [if (isNew) Text('NEW', style: T.overline.copyWith(fontSize: 10.5, color: C.success))]);
}
