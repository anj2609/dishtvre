// Your plan: everything you pay for, grouped, with a remove/undo on each
// item that can be removed. Removals wait until you review and apply.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/plan_store.dart';
import '../checkout/review_screen.dart';
import '../widgets/widgets.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final c = plan.connection;
    const groups = [
      (ItemKind.basePack, 'Base pack', Icons.layers_rounded),
      (ItemKind.alaCarte, 'Channels', Icons.live_tv_rounded),
      (ItemKind.bouquet, 'Bouquets', Icons.dashboard_rounded),
      (ItemKind.addOn, 'Add-ons & services', Icons.add_box_rounded),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(title: 'Your plan', subtitle: c == null ? null : "What's in your ${rupees(c.monthlyRecharge)} a month"),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl),
              children: [
                for (final g in groups)
                  if (plan.itemsOf(g.$1).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: S.lg, bottom: S.sm),
                      child: Row(children: [
                        Icon(g.$3, size: 18, color: C.muted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(g.$2, style: T.section.copyWith(fontSize: 15))),
                        Text(rupees(plan.itemsOf(g.$1).fold(0.0, (a, i) => a + i.price)), style: T.label),
                      ]),
                    ),
                    // Outline only: no fill.
                    Panel(
                      padding: EdgeInsets.zero,
                      color: Colors.transparent,
                      borderColor: C.cardEdge,
                      child: Column(children: [
                        for (final (n, i) in plan.itemsOf(g.$1).indexed) ...[
                          if (n > 0) const Divider(height: 1, color: C.line, indent: S.lg),
                          PlanItemRow(item: i, plan: plan),
                        ],
                      ]),
                    ),
                  ],
                const SizedBox(height: S.lg),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: C.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Prices include GST. Your bill also has the Network Capacity Fee (NCF), set by how many channels you have.', style: T.caption),
                  ),
                ]),
              ],
            ),
          ),
          if (plan.hasChanges)
            BottomBar(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('New bill about', style: T.caption),
                    Text('${rupees(plan.estimate)}/mo', style: T.price.copyWith(fontSize: 19)),
                  ]),
                ),
                SizedBox(
                  width: 160,
                  child: PrimaryButton(
                    label: 'Review',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// One item of the plan: logo, name, details, price, and delete / undo (or
/// a lock when it can't be removed).
class PlanItemRow extends StatelessWidget {
  const PlanItemRow({super.key, required this.item, required this.plan});

  final PlanItem item;
  final PlanStore plan;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final removed = plan.isRemoved(i);
    final detail = [
      if (i.channels > 1) '${i.channels} channels',
      if (i.isHd) 'HD',
      if (i.language.isNotEmpty) i.language,
    ].join(' | ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: removed ? C.dangerSoft.withAlpha(120) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(S.lg, S.md, S.sm, S.md),
      child: Row(children: [
        if (i.logoUrl != null) ...[
          ChannelLogo(name: i.name, url: i.logoUrl, size: 38),
          const SizedBox(width: S.md),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name,
                style: T.item.copyWith(
                  fontSize: 14.5,
                  color: removed ? C.muted : C.ink,
                  decoration: removed ? TextDecoration.lineThrough : null,
                )),
            if (detail.isNotEmpty) Text(detail, style: T.caption),
            if (removed) Text('Will be removed when you apply', style: T.caption.copyWith(color: C.danger, fontWeight: FontWeight.w700)),
            // Price sits under the name so the name gets the full width.
            Text('${rupees(i.price)}/mo', style: T.label.copyWith(color: removed ? C.muted : C.ink)),
          ]),
        ),
        // Delete (or undo); items that can't be removed show a lock.
        if (i.removable)
          IconButton(
            tooltip: removed ? 'Undo removing ${i.name}' : 'Remove ${i.name}',
            onPressed: () => plan.toggleRemove(i),
            icon: Icon(removed ? Icons.undo_rounded : Icons.delete_outline_rounded, size: 22, color: removed ? C.ink : C.danger),
          )
        else
          Tooltip(
            message: '${i.name} can\'t be removed',
            child: const SizedBox(width: 48, height: 48, child: Icon(Icons.lock_outline_rounded, size: 18, color: C.faint)),
          ),
      ]),
    );
  }
}
