// Channel changes: which channels you'd get, keep and lose by switching from
// your pack to another one. Grouped by genre, searchable.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../widgets/widgets.dart';

enum ChannelDiff { added, kept, lost }

class ChannelDiffScreen extends StatefulWidget {
  const ChannelDiffScreen({super.key, required this.pack, required this.packChannels, required this.myChannels, this.initial = ChannelDiff.added});

  final Pack pack;
  final List<Channel> packChannels;
  final List<Channel> myChannels;
  final ChannelDiff initial;

  @override
  State<ChannelDiffScreen> createState() => _ChannelDiffScreenState();
}

class _ChannelDiffScreenState extends State<ChannelDiffScreen> {
  late ChannelDiff _tab = widget.initial;
  late final Map<ChannelDiff, List<Channel>> _lists = _split();
  final _search = TextEditingController();
  String _q = '';

  Map<ChannelDiff, List<Channel>> _split() {
    List<Channel> unique(Iterable<Channel> cs) {
      final seen = <String>{};
      return [
        for (final c in cs)
          if (seen.add(c.key)) c
      ];
    }

    final mine = widget.myChannels.map((c) => c.key).toSet();
    final theirs = widget.packChannels.map((c) => c.key).toSet();
    return {
      ChannelDiff.added: unique(widget.packChannels.where((c) => !mine.contains(c.key))),
      ChannelDiff.kept: unique(widget.packChannels.where((c) => mine.contains(c.key))),
      ChannelDiff.lost: unique(widget.myChannels.where((c) => !theirs.contains(c.key))),
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static (String, String, Color, Color, IconData) _style(ChannelDiff d) => switch (d) {
        ChannelDiff.added => ('New', "Channels you'll get that aren't in your pack now.", C.success, C.successSoft, Icons.add_circle_rounded),
        ChannelDiff.kept => ('You keep', 'Channels you have now that stay with you.', C.info, C.infoSoft, Icons.check_circle_rounded),
        ChannelDiff.lost => ('You lose', "Channels you have now that this pack doesn't include.", C.danger, C.dangerSoft, Icons.remove_circle_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (_, note, fg, bg, icon) = _style(_tab);
    final q = _q.trim().toLowerCase();
    final list = _lists[_tab]!.where((c) => q.isEmpty || c.name.toLowerCase().contains(q)).toList();
    final byGenre = <String, List<Channel>>{};
    for (final c in list) {
      byGenre.putIfAbsent(c.genre, () => []).add(c);
    }
    final genres = byGenre.keys.toList()..sort((a, b) => byGenre[b]!.length.compareTo(byGenre[a]!.length));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: 'Channel changes', subtitle: 'Your pack vs ${widget.pack.name}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.page),
            child: Segmented<ChannelDiff>(
              height: 42,
              options: [for (final d in ChannelDiff.values) (d, '${_style(d).$1} ${_lists[d]!.length}')],
              value: _tab,
              onChanged: (d) => setState(() => _tab = d),
            ),
          ),
          Expanded(
            child: ListView(
              key: PageStorageKey('diff-$_tab'),
              padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.xxl),
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(S.md),
                  // A border in the tab's colour, no fill.
                  decoration: BoxDecoration(border: Border.all(color: fg, width: 1.2)),
                  child: Row(children: [
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(width: S.sm),
                    Expanded(child: Text(note, style: T.caption.copyWith(color: fg, fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: S.md),
                SearchBox(hint: 'Search these channels', controller: _search, onChanged: (v) => setState(() => _q = v)),
                if (list.isEmpty)
                  EmptyNote(
                    title: q.isNotEmpty ? 'No match for “$_q”' : 'No channels here',
                    body: q.isNotEmpty
                        ? 'Try another name.'
                        : switch (_tab) {
                            ChannelDiff.added => 'This pack has nothing your pack doesn’t already have.',
                            ChannelDiff.kept => 'None of your current channels are in this pack.',
                            ChannelDiff.lost => 'You keep every channel you have now.',
                          },
                    icon: q.isNotEmpty ? Icons.search_off_rounded : Icons.tv_off_rounded,
                  )
                else
                  for (final g in genres) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: S.lg, bottom: S.sm),
                      child: Row(children: [
                        Expanded(child: Text(g, style: T.section.copyWith(fontSize: 15))),
                        Text('${byGenre[g]!.length}', style: T.label.copyWith(color: C.muted)),
                      ]),
                    ),
                    Panel(
                      color: Colors.transparent,
                      borderColor: C.cardEdge,
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final (i, c) in byGenre[g]!.indexed) ...[
                          if (i > 0) const Divider(height: 1, color: C.line, indent: 66),
                          ChannelRow(channel: c),
                        ],
                      ]),
                    ),
                  ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// One channel: logo, name, genre | language, and optional tags.
class ChannelRow extends StatelessWidget {
  const ChannelRow({super.key, required this.channel, this.tags = const []});

  final Channel channel;
  final List<Widget> tags;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
      child: Row(children: [
        ChannelLogo(name: c.name, url: c.logoUrl, size: 42),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: T.item.copyWith(fontSize: 14.5)),
            Text([c.genre, if (c.language.isNotEmpty) c.language].join(' | '), style: T.caption),
          ]),
        ),
        if (c.isHd) Text('HD', style: T.overline.copyWith(fontSize: 10.5, color: C.brandDeep)),
        for (final t in tags) ...[const SizedBox(width: 6), t],
      ]),
    );
  }
}
