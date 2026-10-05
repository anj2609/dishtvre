// Compare: your pack and up to two others side by side.
//
// The pack names stay pinned at the top. Below them, the key facts at a
// glance, then channels one genre at a time (only the differences by
// default), so there's little to scroll.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/plan_store.dart';
import '../top_ups/top_ups_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

/// One column: your pack (pack == null) or a pack being compared.
class _Col {
  _Col({required this.tag, required this.name, required this.price, required this.channels, required this.hd, required this.langs, this.pack});

  final String tag;
  final String name;
  final double price;
  final int channels;
  final int hd;
  final List<String> langs;
  final Pack? pack;
}

class _CompareScreenState extends State<CompareScreen> {
  String? _genre;
  bool _onlyDiff = true;
  String? _listsKey;
  Future<List<List<Channel>>>? _lists;

  static const _tickW = 52.0;

  /// One solid colour per column: your pack slate, Pack A violet, Pack B teal.
  static const _colColors = [Color(0xFF4A5470), Color(0xFF6656E0), Color(0xFF0E9488)];
  static Color _colColor(int i) => _colColors[i % _colColors.length];

  /// A lighter shade of the column colour, readable on the dark page.
  static Color _colInk(int i) => Color.lerp(_colColor(i), Colors.white, 0.35)!;

  /// Matches the pack cards' inner padding so the columns line up.
  static const _inset = 10.0;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final base = plan.basePack;
    final cols = <_Col>[
      if (base != null)
        _Col(
            tag: 'YOURS',
            name: base.name,
            price: base.price,
            channels: base.channels,
            hd: base.hdChannels,
            langs: [if (base.language.isNotEmpty) base.language]),
      for (final (i, p) in plan.compare.indexed)
        _Col(tag: 'PACK ${String.fromCharCode(65 + i)}', name: p.name, price: p.price, channels: p.channels, hd: p.hdChannels, langs: p.languages, pack: p),
    ];
    if (plan.compare.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    // One request per set of packs, so a redraw doesn't refetch (or flicker).
    final key = plan.compare.map((p) => p.id).join(',');
    if (key != _listsKey) {
      _listsKey = key;
      _lists = Future.wait([plan.currentChannels(), for (final p in plan.compare) plan.channelsOf(p)]);
    }

    final pin = MediaQuery.sizeOf(context).height >= 700 && MediaQuery.textScalerOf(context).scale(10) <= 13;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: 'Compare packs', subtitle: 'Your pack vs ${plan.compare.length} ${plan.compare.length == 1 ? 'other' : 'others'}'),
          // Pinned when there's room; on short screens or with large text it
          // scrolls with the rest.
          if (pin)
            Padding(
              padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.md),
              child: _heads(cols, plan),
            ),
          Expanded(
            child: FutureBuilder<List<List<Channel>>>(
              future: _lists,
              builder: (context, snap) {
                final sets = snap.data?.map((l) => {for (final c in l) c.key: c}).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.xxl),
                  children: [
                    if (!pin) ...[_heads(cols, plan), const SizedBox(height: S.md)],
                    Reveal(child: _glance(cols)),
                    const SizedBox(height: S.xl),
                    if (sets == null) const Skeleton(height: 240) else Reveal(order: 1, child: _byGenre(cols, sets)),
                  ],
                );
              },
            ),
          ),
          BottomBar(
            child: plan.newBase != null
                ? PrimaryButton(
                    label: 'Continue with ${plan.newBase!.name}',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopUpsScreen(step: 'Step 2 of 3: Optional extras'))),
                  )
                : PrimaryButton(label: 'Back to packs', onTap: () => Navigator.of(context).maybePop()),
          ),
        ]),
      ),
    );
  }

  // Pinned pack cards: tag, full name, price.
  Widget _heads(List<_Col> cols, PlanStore plan) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, c) in cols.indexed) ...[
            if (i > 0) const SizedBox(width: S.sm),
            Expanded(
              child: Builder(builder: (_) {
                final chosen = c.pack != null && plan.newBase?.id == c.pack!.id;
                // Solid colour per pack; a white outline marks the chosen one.
                return Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  decoration: BoxDecoration(color: _colColor(i), border: chosen ? Border.all(color: Colors.white, width: 2) : null),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(chosen ? 'CHOSEN' : c.tag, style: T.overline.copyWith(fontSize: 10, color: const Color(0xD9FFFFFF))),
                    const SizedBox(height: 4),
                    Text(c.name, style: T.label.copyWith(fontSize: 13, height: 1.25, color: Colors.white)),
                    const Spacer(),
                    const SizedBox(height: S.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: rupees(c.price), style: T.item.copyWith(fontSize: 16, color: Colors.white)),
                        TextSpan(text: '/mo', style: T.caption.copyWith(fontSize: 11, color: const Color(0xD9FFFFFF))),
                      ])),
                    ),
                  ]),
                );
              }),
            ),
          ],
        ]),
      );

  // Key facts, one labelled row each, values under each pack.
  Widget _glance(List<_Col> cols) {
    final first = cols.first.price;
    return Panel(
      color: Colors.transparent,
      borderColor: C.cardEdge,
      padding: const EdgeInsets.fromLTRB(0, S.md, 0, S.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: _inset), child: Text('At a glance', style: T.section)),
        const SizedBox(height: S.sm),
        _fact('Monthly price', [for (final c in cols) _value(rupees(c.price))], best: _best([for (final c in cols) c.price], low: true)),
        _fact('Compared with yours', [
          for (final c in cols)
            c.pack == null
                ? _value('—', muted: true)
                : _value(
                    (c.price - first).abs() < 0.5 ? 'Same' : '${rupees((c.price - first).abs())} ${c.price < first ? 'less' : 'more'}',
                    color: (c.price - first).abs() < 0.5 ? C.inkSoft : (c.price < first ? C.success : C.warning),
                  ),
        ]),
        _fact('Channels', [for (final c in cols) _value('${c.channels}')], best: _best([for (final c in cols) c.channels.toDouble()])),
        _fact('HD channels', [for (final c in cols) _value('${c.hd}')], best: _best([for (final c in cols) c.hd.toDouble()])),
        _fact('Languages', [for (final c in cols) _value(c.langs.isEmpty ? '—' : c.langs.join(' | '), muted: c.langs.isEmpty)]),
        _fact(
          'OTT apps',
          [
            for (final c in cols)
              (c.pack?.ottApps ?? const []).isEmpty
                  ? _value('—', muted: true)
                  : Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final o in c.pack!.ottApps) AppLogo(name: o, url: c.pack!.ottLogoUrls[o], size: 28),
                    ]),
          ],
          last: true,
        ),
      ]),
    );
  }

  Widget _value(String text, {Color? color, bool muted = false}) =>
      Text(text, style: T.label.copyWith(fontSize: 13.5, color: muted ? C.faint : (color ?? C.ink)));

  Widget _fact(String label, List<Widget> cells, {List<bool>? best, bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: S.md - 2),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: _inset), child: Text(label, style: T.caption.copyWith(fontSize: 11.5))),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: S.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: _inset - 1, right: 4),
                  alignment: Alignment.centerLeft,
                  child: best != null && best[i]
                      // Best value: a star beside it, no chip behind.
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: cell),
                          const SizedBox(width: 3),
                          const Icon(Icons.star_sharp, size: 14, color: C.brand),
                        ])
                      : cell,
                ),
              ),
            ],
          ]),
        ]),
      );

  List<bool> _best(List<double> v, {bool low = false}) {
    if (v.length < 2) return List.filled(v.length, false);
    final m = v.reduce((a, b) => low ? (a < b ? a : b) : (a > b ? a : b));
    final hits = v.where((x) => x == m).length;
    return [for (final x in v) x == m && hits < v.length];
  }

  // Channels, one genre at a time.
  Widget _byGenre(List<_Col> cols, List<Map<String, Channel>> sets) {
    final all = <String, Channel>{};
    for (final s in sets) {
      for (final c in s.values) {
        all.putIfAbsent(c.key, () => c);
      }
    }
    final counts = <String, int>{};
    for (final c in all.values) {
      counts[c.genre] = (counts[c.genre] ?? 0) + 1;
    }
    final genres = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final g = _genre != null && counts.containsKey(_genre) ? _genre! : genres.first;
    final inGenre = all.values.where((c) => c.genre == g).toList();
    final diff = inGenre.where((c) => !sets.every((s) => s.containsKey(c.key))).toList();
    final rows = _onlyDiff ? diff : inGenre;
    final per = [for (final s in sets) s.values.where((c) => c.genre == g).length];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Channels by genre', style: T.section),
      const SizedBox(height: S.md),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            for (final x in genres)
              Padding(
                padding: const EdgeInsets.only(right: S.sm),
                child: Pick(label: x, selected: x == g, onTap: () => setState(() => _genre = x)),
              ),
          ],
        ),
      ),
      const SizedBox(height: S.md),
      Panel(
        color: Colors.transparent,
        borderColor: C.cardEdge,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // How many channels of this genre each pack has.
          Padding(
            padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.sm),
            child: Row(children: [
              Expanded(child: Text('$g channels', style: T.label.copyWith(color: C.muted, fontSize: 12.5))),
              for (final (i, n) in per.indexed)
                SizedBox(
                  width: _tickW,
                  child: Column(children: [
                    Text(i == 0 ? 'Yours' : String.fromCharCode(64 + i), style: T.overline.copyWith(fontSize: 10, color: _colInk(i))),
                    Text('$n',
                        style: T.item.copyWith(fontSize: 15, color: n == per.reduce((a, b) => a > b ? a : b) && per.toSet().length > 1 ? C.brandDeep : C.ink)),
                  ]),
                ),
            ]),
          ),
          // Show all or only what differs.
          Padding(
            padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.sm),
            child: Row(children: [
              Pick(label: 'Only differences', selected: _onlyDiff, onTap: () => setState(() => _onlyDiff = !_onlyDiff)),
              const Spacer(),
              Text('${rows.length} of ${inGenre.length}', style: T.caption),
            ]),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(S.lg, S.sm, S.lg, S.lg),
              child: Text('Every pack here has the same $g channels.', style: T.body),
            )
          else
            for (final c in rows) _channelRow(c, sets),
        ]),
      ),
      const SizedBox(height: S.md),
      Text('★ marks the better value. Prices include GST; NCF is charged separately.', style: T.caption),
    ]);
  }

  Widget _channelRow(Channel c, List<Map<String, Channel>> sets) => Container(
        padding: const EdgeInsets.fromLTRB(S.md, 8, S.md, 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
        child: Row(children: [
          ChannelLogo(name: c.name, url: c.logoUrl, size: 34),
          const SizedBox(width: S.md - 2),
          Expanded(child: Text(c.name, style: T.label.copyWith(fontSize: 13))),
          for (final (col, s) in sets.indexed)
            SizedBox(
              width: _tickW,
              child: Center(
                child: Semantics(
                  label: s.containsKey(c.key) ? 'Included' : 'Not included',
                  child: ExcludeSemantics(
                    child:
                        s.containsKey(c.key) ? Icon(Icons.check_sharp, size: 20, color: _colInk(col)) : Container(width: 12, height: 2, color: C.lineStrong),
                  ),
                ),
              ),
            ),
        ]),
      );
}
