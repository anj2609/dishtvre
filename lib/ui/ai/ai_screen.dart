// Find my pack (AI recommender): five short questions, one per screen,
// then three suggestions with the reasons they fit. Choosing one continues
// into the same optional extras → review → apply flow as Explore.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../explore/pack_details_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  AiOptions? _opts;
  final AiAnswers _a = AiAnswers();
  int _q = 0;
  bool _forward = true;
  List<Recommendation>? _recs;
  bool _loadingRecs = false;

  static const _total = 5;

  @override
  void initState() {
    super.initState();
    final repo = context.read<AppStore>().repo;
    _a.hd = context.read<AppStore>().connection?.isHd ?? false;
    repo.aiOptions().then((o) {
      if (mounted) setState(() => _opts = o);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<AppStore>().connection;
      if (c != null) context.read<PlanStore>().open(c);
    });
  }

  bool get _canNext => switch (_q) {
        0 => _a.languages.isNotEmpty,
        1 => _a.genres.length >= 2,
        2 => _a.viewing != null,
        3 => true,
        _ => _a.budget != null,
      };

  Future<void> _next() async {
    if (_q < _total - 1) {
      setState(() {
        _forward = true;
        _q++;
      });
      return;
    }
    setState(() => _loadingRecs = true);
    final r = await context.read<AppStore>().repo.recommend(_a);
    if (!mounted) return;
    setState(() {
      _recs = r;
      _loadingRecs = false;
    });
  }

  void _back() {
    if (_recs != null) return setState(() => _recs = null);
    if (_q > 0) {
      setState(() {
        _forward = false;
        _q--;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _q == 0 && _recs == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Header(
              title: _recs == null ? 'Find my pack' : 'Packs for you',
              subtitle: _recs == null ? 'Tell us what you watch' : 'Based on your answers',
              onBack: _back,
            ),
            Expanded(
              child:
                  _opts == null ? ListView(children: const [Skeleton(height: 60), Skeleton(height: 220)]) : (_recs == null ? _questions() : _recommendations()),
            ),
            if (_recs == null)
              BottomBar(
                child: Row(children: [
                  if (_q > 0) ...[
                    SizedBox(width: 110, child: SecondaryButton(label: 'Back', onTap: _back)),
                    const SizedBox(width: S.md),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      label: _q == _total - 1 ? 'Show my packs' : 'Next',
                      busy: _loadingRecs,
                      onTap: _canNext ? _next : null,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- questions

  Widget _questions() {
    final o = _opts!;
    final (IconData icon, String title, String hint, List<Widget> choices) = switch (_q) {
      0 => (
          Icons.translate_sharp,
          'Which languages do you watch?',
          'Pick at least one.',
          [
            for (final l in o.languages)
              Pick(
                  label: l,
                  selected: _a.languages.contains(l),
                  onTap: () => setState(() => _a.languages.contains(l) ? _a.languages.remove(l) : _a.languages.add(l))),
          ]
        ),
      1 => (
          Icons.favorite_sharp,
          'What do you love watching?',
          'Pick at least two.',
          [
            for (final g in o.genres)
              Pick(label: g, selected: _a.genres.contains(g), onTap: () => setState(() => _a.genres.contains(g) ? _a.genres.remove(g) : _a.genres.add(g))),
          ]
        ),
      2 => (
          Icons.weekend_sharp,
          'How do you like to watch?',
          'Pick one.',
          [for (final v in o.viewing) Pick(label: v, selected: _a.viewing == v, onTap: () => setState(() => _a.viewing = v))]
        ),
      3 => (
          Icons.hd_sharp,
          'Which picture quality?',
          'HD needs an HD box.',
          [
            Pick(label: 'SD', selected: !_a.hd, onTap: () => setState(() => _a.hd = false)),
            Pick(label: 'HD', selected: _a.hd, onTap: () => setState(() => _a.hd = true)),
          ]
        ),
      _ => (
          Icons.savings_sharp,
          "What's your monthly budget?",
          'You can still add extras later.',
          [for (final b in o.budgets) Pick(label: 'Up to ${rupees(b)}', selected: _a.budget == b, onTap: () => setState(() => _a.budget = b))]
        ),
    };
    final count = switch (_q) { 0 => _a.languages.length, 1 => _a.genres.length, _ => 0 };
    return ListView(key: const PageStorageKey('ai-questions'), padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl), children: [
      Row(children: [
        Expanded(child: Text('Question ${_q + 1} of $_total', style: T.label.copyWith(color: C.brandDeep))),
        if (count > 0) Tag('$count selected', fg: C.brandDeep, bg: C.brandSoft),
      ]),
      const SizedBox(height: S.sm),
      Row(children: [
        for (var i = 0; i < _total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 5,
              decoration: BoxDecoration(color: i <= _q ? C.brand : C.line, borderRadius: BorderRadius.zero),
            ),
          ),
        ],
      ]),
      const SizedBox(height: S.xxl),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, a) {
          final incoming = child.key == ValueKey(_q);
          final dx = incoming == _forward ? 0.1 : -0.1;
          return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child));
        },
        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
        child: Column(key: ValueKey(_q), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: C.brandSoft, borderRadius: BorderRadius.zero),
            child: Icon(icon, color: C.brand, size: 26),
          ),
          const SizedBox(height: S.lg),
          Text(title, style: T.display.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Text(hint, style: T.body.copyWith(color: C.muted)),
          const SizedBox(height: S.xl),
          Wrap(spacing: 8, runSpacing: 10, children: choices),
        ]),
      ),
    ]);
  }

  // -------------------------------------------------------- recommendations

  Widget _recommendations() {
    final plan = context.watch<PlanStore>();
    final current = plan.basePack?.price ?? 0;
    return ListView(key: const PageStorageKey('ai-results'), padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl), children: [
      Text('Tap a pack to see its channels and choose it.', style: T.body),
      const SizedBox(height: S.lg),
      for (final r in _recs!) ...[
        _recCard(r, current, plan),
        const SizedBox(height: S.md),
      ],
      Center(
        child: TextButton(
          onPressed: () => setState(() {
            _recs = null;
            _q = 0;
          }),
          child: Text('Change my answers', style: T.label.copyWith(color: C.brandDeep)),
        ),
      ),
    ]);
  }

  // A compact pick: outline only (orange for the best match), no fills.
  Widget _recCard(Recommendation r, double current, PlanStore plan) {
    final p = r.pack;
    final d = current > 0 ? p.price - current : null;
    final first = r == _recs!.first;
    return Panel(
      color: Colors.transparent,
      borderColor: first ? C.brand : C.cardEdge,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PackDetailsScreen(pack: p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: S.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(r.label, style: T.overline.copyWith(fontSize: 10.5, color: first ? C.brand : C.muted)),
                Text('${r.matchScore}% match', style: T.overline.copyWith(fontSize: 10.5, color: C.success)),
              ]),
              Text(p.name, style: T.item.copyWith(fontSize: 15.5, height: 1.25)),
              Text('${p.channels} channels | ${p.hdChannels} HD', style: T.caption.copyWith(fontSize: 12)),
            ]),
          ),
          const SizedBox(width: S.sm),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.34),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: rupees(p.price), style: T.price.copyWith(fontSize: 19)),
                  TextSpan(text: '/mo', style: T.caption.copyWith(fontSize: 11)),
                ])),
              ),
              if (d != null)
                Text(d.abs() < 0.5 ? 'Same as now' : '${rupees(d.abs())} ${d < 0 ? 'less' : 'more'}',
                    textAlign: TextAlign.end, style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: d <= 0 ? C.success : C.warning)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // A peek at the channels in this pack.
        FutureBuilder<List<Channel>>(
          future: plan.channelsOf(p),
          builder: (context, snap) {
            final logos = showcase(snap.data ?? const [], 7);
            return SizedBox(
              height: 30,
              child: Row(children: [
                for (final (i, l) in logos.indexed)
                  Align(
                    widthFactor: i == logos.length - 1 ? 1 : 0.75,
                    child: ChannelLogo(name: l.$1, url: l.$2, size: 30),
                  ),
                if (logos.isNotEmpty) ...[
                  const SizedBox(width: S.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('+${p.channels - logos.length} more', maxLines: 1, softWrap: false, style: T.label.copyWith(color: C.muted, fontSize: 12)),
                    ),
                  ),
                ],
              ]),
            );
          },
        ),
        if (r.reasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          // The top two reasons, one line each.
          for (final why in r.reasons.take(2))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_sharp, size: 15, color: C.success),
              const SizedBox(width: 6),
              Expanded(child: Text(why, style: T.caption.copyWith(fontSize: 12.5, color: C.inkSoft))),
            ]),
        ],
      ]),
    );
  }
}
