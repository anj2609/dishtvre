// Add channels & services: single channels, bouquets and add-ons.
//
// Used on its own (from Change pack / Home) and as the optional middle step
// after choosing a pack in Explore or the AI recommender.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../checkout/review_screen.dart';
import '../widgets/widgets.dart';
import '../checkout/new_bill.dart';

class TopUpsScreen extends StatefulWidget {
  const TopUpsScreen({super.key, this.step});

  /// e.g. "Step 2 of 3: Optional extras" when part of a pack switch.
  final String? step;

  @override
  State<TopUpsScreen> createState() => _TopUpsScreenState();
}

class _TopUpsScreenState extends State<TopUpsScreen> {
  ItemKind _kind = ItemKind.alaCarte;
  String _q = '';
  String? _lang;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final plan = context.read<PlanStore>();
      final c = context.read<AppStore>().connection;
      if (c != null) await plan.open(c);
      for (final k in const [ItemKind.alaCarte, ItemKind.bouquet, ItemKind.addOn]) {
        plan.loadCatalog(k);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final all = plan.catalog(_kind);
    final langs =
        _kind == ItemKind.alaCarte && all != null ? (all.map((i) => i.language).where((l) => l.isNotEmpty).toSet().toList()..sort()) : const <String>[];
    final q = _q.trim().toLowerCase();
    final items = (all ?? const <PlanItem>[]).where((i) {
      if (_lang != null && i.language != _lang) return false;
      return q.isEmpty || i.name.toLowerCase().contains(q) || i.broadcaster.toLowerCase().contains(q);
    }).toList();
    final addedHere = plan.added.where((i) => i.kind == _kind).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: 'Add channels & services', subtitle: widget.step ?? 'Pay only for what you watch'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.page),
            child: Segmented<ItemKind>(
              height: 42,
              options: const [
                (ItemKind.alaCarte, 'Channels'),
                (ItemKind.bouquet, 'Bouquets'),
                (ItemKind.addOn, 'Add-ons'),
              ],
              value: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                _lang = null;
                _search.clear();
                _q = '';
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: S.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, 0),
                  child: Text(
                    switch (_kind) {
                      ItemKind.alaCarte => 'Pick single channels you love.',
                      ItemKind.bouquet => 'Bundles from one broadcaster — usually cheaper than buying the channels one by one.',
                      _ => 'Extra packs and services like Recording.',
                    },
                    style: T.body,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, 0),
                  child: SearchBox(
                    hint: _kind == ItemKind.alaCarte ? 'Search channels' : 'Search packs',
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                if (langs.length > 1)
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, 0),
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pick(label: 'All', selected: _lang == null, onTap: () => setState(() => _lang = null))),
                        for (final l in langs)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pick(label: l, selected: _lang == l, onTap: () => setState(() => _lang = _lang == l ? null : l)),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, S.sm),
                  child: Row(children: [
                    Expanded(child: Text('${items.length} ${_kind == ItemKind.alaCarte ? 'channels' : 'options'}', style: T.label)),
                    if (addedHere > 0) BrandShade(child: Text('$addedHere added', style: T.label.copyWith(color: C.brand))),
                  ]),
                ),
                if (all == null)
                  for (var i = 0; i < 4; i++) const Skeleton(height: 72)
                else if (items.isEmpty)
                  EmptyNote(
                    title: q.isEmpty ? 'Nothing more to add here' : 'No match for “$_q”',
                    body: q.isEmpty ? 'You already have everything in this list.' : 'Try another name.',
                    action: q.isEmpty ? null : 'Clear search',
                    onAction: () => setState(() {
                      _search.clear();
                      _q = '';
                    }),
                  )
                else
                  for (final i in items)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm),
                      child: _ItemCard(key: ValueKey('topup-${i.id}'), item: i, plan: plan),
                    ),
              ],
            ),
          ),
          _footer(plan),
        ]),
      ),
    );
  }

  Widget _footer(PlanStore plan) => BottomBar(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(plan.hasChanges ? 'New bill' : 'Your bill', style: T.caption),
              NewBill(plan, style: T.price.copyWith(fontSize: 19)),
            ]),
          ),
          SizedBox(
            width: 168,
            child: PrimaryButton(
              label: plan.hasChanges ? 'Review' : 'Done',
              onTap: plan.hasChanges
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen()))
                  : () => Navigator.of(context).maybePop(),
            ),
          ),
        ]),
      );
}

/// One slim row: logo, name and details, price, and a round add toggle.
class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.plan});

  final PlanItem item;
  final PlanStore plan;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final added = plan.isAdded(i);
    final initials =
        i.name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp('[A-Za-z0-9&]').hasMatch(w[0])).take(2).map((w) => w[0].toUpperCase()).join();
    final meta = [
      if (i.kind != ItemKind.alaCarte && i.channels > 0) '${i.channels} channels',
      if (i.isHd) 'HD',
      if (i.language.isNotEmpty) i.language,
      if (i.broadcaster.isNotEmpty) i.broadcaster,
    ].join(' | ');
    void toggle() => added ? plan.undoAdd(i) : plan.add(i);

    return Semantics(
      container: true,
      button: true,
      selected: added,
      label: added ? 'Remove ${i.name} from your changes' : 'Add ${i.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          toggle();
        },
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            // Outline only; coral when added.
            decoration: BoxDecoration(border: Border.all(color: added ? C.brand : C.cardEdge, width: added ? 1.5 : 1)),
            padding: const EdgeInsets.fromLTRB(S.md, 10, 10, 10),
            child: Row(children: [
              if (i.logoUrl != null)
                ChannelLogo(name: i.name, url: i.logoUrl, size: 40)
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: i.isRecordingPlan ? C.danger : C.lineStrong, width: 1.5)),
                  child: i.isRecordingPlan
                      ? Icon(Icons.fiber_manual_record_sharp, color: C.danger, size: 18)
                      : BrandShade(child: Text(initials, style: T.label.copyWith(color: C.brandDeep, fontSize: 12))),
                ),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: T.item.copyWith(fontSize: 14.5)),
                  if (meta.isNotEmpty) Text(meta, style: T.caption.copyWith(fontSize: 12)),
                  if (i.isRecordingPlan) Text('Pick 1 month or 12 months', style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
                  // Price under the name so long names never get squeezed.
                  Text.rich(TextSpan(children: [
                    TextSpan(text: rupees(i.price), style: T.label.copyWith(fontSize: 14)),
                    TextSpan(text: '/month', style: T.caption.copyWith(fontSize: 11)),
                  ])),
                ]),
              ),
              const SizedBox(width: S.md - 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: added
                    ? const BoxDecoration(gradient: G.brand, shape: BoxShape.circle)
                    : BoxDecoration(
                        color: null,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.brand.withValues(alpha: 0.5)),
                      ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: BrandShade(
                    key: ValueKey(added),
                    on: !added,
                    child: Icon(
                      added ? Icons.check_sharp : Icons.add_sharp,
                      size: 20,
                      color: added ? Colors.white : C.brand,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
