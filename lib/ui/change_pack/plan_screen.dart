// Your plan: everything you pay for, grouped, with a remove/undo on each
// item that can be removed. Removals wait until you review and apply.
// With readOnly (My Pack) it only shows what's in the plan: no editing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/plan_store.dart';
import '../checkout/review_screen.dart';
import '../widgets/widgets.dart';
import '../checkout/new_bill.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, this.readOnly = false});

  /// Showcase only: hides remove/undo, locks and the review bar.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final c = plan.connection;
    const groups = [
      (ItemKind.basePack, 'Base pack', Icons.layers_sharp),
      (ItemKind.alaCarte, 'Channels', Icons.live_tv_sharp),
      (ItemKind.bouquet, 'Bouquets', Icons.dashboard_sharp),
      (ItemKind.addOn, 'Add-ons & services', Icons.add_box_sharp),
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
                      padding: const EdgeInsets.only(top: S.xl, bottom: S.sm + 2),
                      child: Row(children: [
                        Expanded(child: Text(g.$2, style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
                        Text(rupees(plan.itemsOf(g.$1).fold(0.0, (a, i) => a + i.price)), style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                      ]),
                    ),
                    // Items straight on the page: no panel behind them and no
                    // lines between them; spacing does the work.
                    Column(children: [
                      for (final i in plan.itemsOf(g.$1)) PlanItemRow(item: i, plan: plan, readOnly: readOnly, flush: true),
                    ]),
                  ],
                const SizedBox(height: S.lg),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_sharp, size: 16, color: C.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Prices include GST. Your bill also has the Network Capacity Fee (NCF), set by how many channels you have.', style: T.caption),
                  ),
                ]),
              ],
            ),
          ),
          if (!readOnly && plan.hasChanges)
            BottomBar(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('New bill', style: T.caption),
                    NewBill(plan, style: T.price.copyWith(fontSize: 19)),
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
  const PlanItemRow({super.key, required this.item, required this.plan, this.readOnly = false, this.flush = false});

  final PlanItem item;
  final PlanStore plan;
  final bool readOnly;

  /// Sitting straight on the page (no panel), so no left inset.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final removed = !readOnly && plan.isRemoved(i);
    final detail = [
      if (i.channels > 1) '${i.channels} channels',
      if (i.isHd) 'HD',
      if (i.language.isNotEmpty) i.language,
    ].join('  ·  ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(flush ? 0 : S.lg, S.md, flush ? 0 : S.sm, S.md),
      child: Row(children: [
        if (i.logoUrl != null) ...[
          ChannelLogo(name: i.name, url: i.logoUrl, size: 38),
          const SizedBox(width: S.md),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name,
                style: T.item.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: removed ? C.muted : C.ink,
                  decoration: removed ? TextDecoration.lineThrough : null,
                )),
            if (detail.isNotEmpty) ...[const SizedBox(height: 2), Text(detail, style: T.caption.copyWith(fontSize: 12, color: C.muted))],
            if (removed) Text('Will be removed when you apply', style: T.caption.copyWith(color: C.danger, fontWeight: FontWeight.w700)),
            // Price sits under the name so the name gets the full width.
            const SizedBox(height: 2),
            Text('${rupees(i.price)}/mo', style: T.label.copyWith(fontSize: 12.5, color: removed ? C.muted : C.inkSoft)),
          ]),
        ),
        // Delete (or undo); items that can't be removed show a lock.
        if (readOnly)
          const SizedBox(width: S.sm)
        else if (i.removable)
          IconButton(
            tooltip: removed ? 'Undo removing ${i.name}' : 'Remove ${i.name}',
            onPressed: () => plan.toggleRemove(i),
            icon: Icon(removed ? Icons.undo_sharp : Icons.delete_outline_sharp, size: 22, color: removed ? C.ink : C.danger),
          )
        else
          Tooltip(
            message: '${i.name} can\'t be removed',
            child: SizedBox(width: 48, height: 48, child: Icon(Icons.lock_outline_sharp, size: 18, color: C.faint)),
          ),
      ]),
    );
  }
}
