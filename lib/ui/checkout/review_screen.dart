// Review: the server-priced new bill first, then each change, then the bill
// breakdown, then one Confirm & apply.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/plan_store.dart';
import '../widgets/widgets.dart';
import 'success_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PlanStore>();
      if (p.quote == null) p.review();
    });
  }

  Future<void> _apply() async {
    final p = context.read<PlanStore>();
    final ok = await p.apply();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
        (r) => r.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We couldn’t apply this change. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlanStore>();
    final q = p.quote;
    final applying = p.applyState == ApplyState.applying;
    return PopScope(
      canPop: !applying,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Header(title: 'Review', subtitle: 'Check your changes before applying'),
            Expanded(
              child: q == null
                  ? (p.applyState == ApplyState.failed
                      ? EmptyNote(
                          icon: Icons.cloud_off_sharp,
                          title: 'We couldn’t price this change',
                          action: 'Try again',
                          onAction: p.review,
                        )
                      : ListView(children: const [Skeleton(height: 120), Skeleton(height: 90), Skeleton(height: 160)]))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.xxl),
                      children: [
                        _summary(q.total, p.currentTotal),
                        const SizedBox(height: S.xl),
                        Text('Your changes', style: T.section),
                        const SizedBox(height: S.sm),
                        if (p.newBase != null) ...[
                          _group('Switching to', Icons.swap_horiz_sharp, C.brand, C.brandSoft, [
                            (p.newBase!.name, '${rupees(p.newBase!.price)}/mo', '${p.newBase!.channels} channels', null),
                          ]),
                          if (p.basePack != null)
                            _group(
                                'Replacing',
                                Icons.history_sharp,
                                C.muted,
                                C.sunken,
                                [
                                  (p.basePack!.name, rupees(-p.basePack!.price, signed: true), null, null),
                                ],
                                strike: true),
                        ],
                        if (p.added.isNotEmpty)
                          _group('Adding', Icons.add_sharp, C.success, C.successSoft, [
                            for (final i in p.added) (i.name, rupees(i.price, signed: true), _kindLabel(i), i.logoUrl),
                          ]),
                        if (p.removed.isNotEmpty)
                          _group(
                              'Removing',
                              Icons.remove_sharp,
                              C.danger,
                              C.dangerSoft,
                              [
                                for (final i in p.removed) (i.name, rupees(-i.price, signed: true), _kindLabel(i), i.logoUrl),
                              ],
                              strike: true),
                        const SizedBox(height: S.lg),
                        Text('Bill breakdown', style: T.section),
                        const SizedBox(height: S.sm),
                        Panel(
                          color: Colors.transparent,
                          borderColor: C.cardEdge,
                          child: Column(children: [
                            _row('Packs and channels', rupees(q.packCost)),
                            if (q.discount > 0) _row('Loyalty discount', rupees(-q.discount, signed: true), color: C.success),
                            _row('Network Capacity Fee', rupees(q.ncf)),
                            _row('GST (18%)', rupees(q.gst)),
                            Padding(padding: EdgeInsets.symmetric(vertical: S.sm), child: Divider(height: 1, color: C.line)),
                            Row(children: [
                              Expanded(child: Text('New monthly bill', style: T.section)),
                              Text(rupees(q.total), style: T.price.copyWith(fontSize: 19)),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: S.lg),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.bolt_sharp, size: 18, color: C.muted),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Changes apply as soon as you confirm. Your next recharge uses the new bill.', style: T.caption)),
                        ]),
                      ],
                    ),
            ),
            BottomBar(
              child: PrimaryButton(
                label: 'Confirm & apply',
                subtitle: q == null ? null : 'New bill ${rupees(q.total)}/month',
                busy: applying,
                onTap: q == null ? null : _apply,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _kindLabel(PlanItem i) => switch (i.kind) {
        ItemKind.alaCarte => 'Channel',
        ItemKind.bouquet => 'Bouquet of ${i.channels} channels',
        ItemKind.addOn => i.group == 'OTT' ? 'OTT app' : (i.channels > 0 ? 'Add-on with ${i.channels} channels' : 'Service'),
        ItemKind.basePack => 'Base pack',
      };

  // The new bill on the card orange gradient, like the Home TV card.
  Widget _summary(double total, double current) {
    final d = total - current;
    final same = d.abs() < 0.5;
    const soft = Color(0xE6FFFFFF);
    return Container(
      padding: const EdgeInsets.all(S.lg),
      decoration: const BoxDecoration(gradient: G.brand),
      child: Row(children: [
        const Icon(Icons.receipt_long_sharp, color: Colors.white, size: 34),
        const SizedBox(width: S.md + 2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR NEW MONTHLY BILL', style: T.overline.copyWith(color: soft)),
            const SizedBox(height: 2),
            Text(rupees(total), style: T.display.copyWith(fontSize: 28, color: Colors.white)),
            const SizedBox(height: 6),
            // Plain text on the orange; a saving shows in green.
            Text(
              same ? 'Same as now' : '${rupees(d.abs())} ${d < 0 ? 'less' : 'more'} a month',
              style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: d < 0 && !same ? const Color(0xFF0B6B32) : Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _group(String title, IconData icon, Color fg, Color bg, List<(String, String, String?, String?)> rows, {bool strike = false}) => Padding(
        padding: const EdgeInsets.only(bottom: S.sm + 2),
        child: Panel(
          color: Colors.transparent,
          borderColor: C.cardEdge,
          padding: const EdgeInsets.fromLTRB(S.lg, S.md + 2, S.lg, S.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 28,
                height: 28,
                color: Color.alphaBlend(bg, C.cardTop),
                child: BrandShade(on: fg == C.brand, child: Icon(icon, size: 17, color: fg)),
              ),
              const SizedBox(width: S.sm),
              Expanded(child: Text(title.toUpperCase(), style: T.overline.copyWith(color: fg))),
              if (rows.length > 1) Text('${rows.length}', style: T.caption),
            ]),
            const SizedBox(height: 4),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (r.$4 != null) ...[ChannelLogo(name: r.$1, url: r.$4, size: 36), const SizedBox(width: S.md - 2)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.$1,
                          style: T.item.copyWith(fontSize: 14.5, color: strike ? C.muted : C.ink, decoration: strike ? TextDecoration.lineThrough : null)),
                      if (r.$3 != null) Text(r.$3!, style: T.caption),
                    ]),
                  ),
                  const SizedBox(width: S.sm),
                  Text(r.$2, style: T.label.copyWith(color: fg == C.muted ? C.muted : (fg == C.brand ? C.ink : fg))),
                ]),
              ),
          ]),
        ),
      );

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: T.body.copyWith(color: color ?? C.inkSoft))),
          Text(value, style: T.label.copyWith(color: color ?? C.ink)),
        ]),
      );
}
