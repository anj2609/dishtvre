// Change pack: a hub for the three ways to change what you watch.
//
// The features come first: Explore packs is the hero card with channel
// logos gliding past, the AI pack finder and Add-ons sit side by side under
// it. Your current pack is one slim row at the top that opens the full plan.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../ai/ai_screen.dart';
import '../checkout/review_screen.dart';
import '../explore/explore_screen.dart';
import '../home/connection_card.dart';
import '../top_ups/top_ups_screen.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'plan_screen.dart';
import 'switch_tv_sheet.dart';
import '../checkout/new_bill.dart';
import '../checkout/plan_exit_guard.dart';

class ChangePackScreen extends StatefulWidget {
  const ChangePackScreen({super.key});

  @override
  State<ChangePackScreen> createState() => _ChangePackScreenState();
}

class _ChangePackScreenState extends State<ChangePackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    final c = context.read<AppStore>().connection;
    if (c != null) context.read<PlanStore>().open(c);
  }

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _switchTv() async {
    final vc = await showSwitchTvSheet(context);
    if (vc == null || !mounted) return;
    context.read<AppStore>().selectVc(vc);
    _open();
  }

  bool get _narrow => MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(10) > 13;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final plan = context.watch<PlanStore>();
    final c = app.connection;

    return PlanExitGuard(
        child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Header(
            plainBack: true,
            inline: true,
            title: 'Change pack',
            // Non-breaking spaces keep the VC number on one line.
            subtitle: c == null ? null : '${c.label} · VC\u00A0${c.vcPretty.replaceAll(' ', '\u00A0')}',
            trailing: app.connections.length > 1 ? _switchPill() : null,
          ),
          Expanded(
            child: FutureBuilder<List<Channel>>(
              future: plan.currentChannels(),
              builder: (context, snap) {
                final logos = showcase(snap.data ?? const [], 16);
                return ListView(
                  padding: EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.xxl + MediaQuery.paddingOf(context).bottom),
                  children: [
                    if (c == null || (plan.loadingItems && plan.items.isEmpty))
                      Container(height: 76, decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.zero))
                    else
                      Reveal(child: _currentPack(c, plan.basePack)),
                    if (plan.hasChanges) ...[const SizedBox(height: S.md), Reveal(child: _pendingBanner(plan))],
                    const SizedBox(height: S.xl),
                    Reveal(order: 1, child: Text('CHANGE YOUR PACK', style: T.overline)),
                    const SizedBox(height: S.md),
                    Reveal(order: 1, child: _explore(logos)),
                    const SizedBox(height: S.md),
                    Reveal(order: 2, child: _tiles(logos)),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    ));
  }

  // Outlined, slightly rounded, and nudged towards the screen edge.
  // Outlined, slightly rounded, nudged towards the screen edge. On narrow
  // screens or with large text it shrinks to just the icon (label as tooltip).
  Widget _switchPill() {
    final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(10) > 12;
    return Transform.translate(
      offset: const Offset(10, 0),
      child: Tooltip(
        message: 'Switch TV',
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: C.ink, width: 1.2)),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: _switchTv,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 10 : 9),
              child: compact
                  ? Icon(Icons.swap_horiz_sharp, size: 20, color: C.ink)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.swap_horiz_sharp, size: 18, color: C.ink),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Switch TV', maxLines: 1, softWrap: false, style: T.label)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _currentPack(Connection c, PlanItem? base) {
    final (accent, soft) = accentOf(c.status);
    return Pressable(
      onTap: () => _go(const PlanScreen()),
      child: Container(
        // Plain: no background or border.
        padding: const EdgeInsets.symmetric(vertical: S.sm),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(Icons.tv_sharp, color: accent, size: 20),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('CURRENT PACK', style: T.overline)),
                BrandShade(child: Text('Your plan', style: T.label.copyWith(color: C.brandDeep, fontSize: 12))),
                BrandShade(child: Icon(Icons.chevron_right_sharp, color: C.brandDeep, size: 18)),
              ]),
              Text(base?.name ?? c.planName, style: T.item.copyWith(fontSize: 16)),
              Text(
                [if (base != null) '${base.channels} channels', '${rupees(c.monthlyRecharge)}/month'].join(' | '),
                style: T.caption,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pendingBanner(PlanStore plan) => Pressable(
        onTap: () => _go(const ReviewScreen()),
        child: Container(
          padding: const EdgeInsets.all(S.md + 2),
          decoration: BoxDecoration(color: C.cardTop, border: Border.all(color: C.brand)),
          child: Row(children: [
            BrandShade(child: Icon(Icons.pending_actions_sharp, color: C.brandDeep)),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BrandShade(
                    child: Text('${plan.changeCount} ${plan.changeCount == 1 ? 'change' : 'changes'} not applied yet',
                        style: T.item.copyWith(color: C.brandDeep))),
                Text('${newBillLine(plan)} | Tap to review', style: T.caption),
              ]),
            ),
            BrandShade(child: Icon(Icons.chevron_right_sharp, color: C.brandDeep)),
          ]),
        ),
      );

  // Explore packs: the hero, with channel logos gliding past.
  Widget _explore(List<(String, String?)> logos) {
    return Pressable(
      label: 'Explore packs. TV and OTT packs, compare and switch',
      onTap: () => _go(const ExploreScreen()),
      child: Container(
        decoration: BoxDecoration(
          color: C.explore,
          border: Border.all(color: const Color(0xFFB8361A)),
          boxShadow: D.lift,
        ),
        padding: const EdgeInsets.fromLTRB(S.lg, 14, S.lg, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Explore packs', style: T.title.copyWith(fontSize: 20, color: Colors.white)),
                Text('Compare and switch TV and OTT packs', style: T.caption.copyWith(color: _onSoft)),
              ]),
            ),
            const SizedBox(width: S.md),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_sharp, color: C.explore, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          LogoMarquee(logos: logos, size: 36, gap: 8),
        ]),
      ),
    );
  }

  // AI pack finder and Add-ons, side by side (stacked when space is tight).
  Widget _tiles(List<(String, String?)> logos) {
    final ai = _tile(
      color: C.ai,
      icon: Icons.auto_awesome_sharp,
      tag: 'AI',
      title: 'Find my pack',
      sub: '5 quick questions',
      label: 'Find my pack. AI picks a pack from 5 quick questions',
      onTap: () => _go(const AiScreen()),
    );
    final addOns = _tile(
      color: C.addOns,
      icon: Icons.add_sharp,
      title: 'Add-ons',
      sub: 'Channels and more',
      label: 'Add-ons. Add channels, bouquets and Recording',
      onTap: () => _go(const TopUpsScreen()),
      art: _logoStack(logos.reversed.take(3).toList()),
    );
    return _narrow
        ? Column(children: [ai, const SizedBox(height: S.md), addOns])
        : IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: ai),
              const SizedBox(width: S.md),
              Expanded(child: addOns),
            ]),
          );
  }

  Widget _tile({
    required Color color,
    required IconData icon,
    required String title,
    required String sub,
    required String label,
    required VoidCallback onTap,
    Widget? art,
    String? tag,
  }) {
    return Pressable(
      label: label,
      onTap: onTap,
      child: Glow(
        color: color,
        strength: 1,
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _iconBadge(icon),
              const Spacer(),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  color: Colors.white,
                  child: Text(tag, style: T.label.copyWith(color: color, fontSize: 11.5)),
                )
              else if (art != null)
                art,
            ]),
            const SizedBox(height: S.xxl + S.sm),
            Text(title, style: T.section.copyWith(fontSize: 17.5, color: Colors.white)),
            const SizedBox(height: 2),
            Text(sub, style: T.caption.copyWith(color: _onSoft)),
          ]),
        ),
      ),
    );
  }

  /// Soft white text on the solid feature colours.
  static const _onSoft = Color(0xD9FFFFFF);

  Widget _iconBadge(IconData icon) => Container(
        width: 44,
        height: 44,
        child: Icon(icon, color: Colors.white, size: 22),
      );

  Widget _logoStack(List<(String, String?)> logos) => SizedBox(
        width: 30.0 + 18 * (logos.length - 1).clamp(0, 2),
        height: 30,
        child: Stack(children: [
          for (final (i, l) in logos.indexed) Positioned(left: i * 18.0, child: ChannelLogo(name: l.$1, url: l.$2, size: 30)),
        ]),
      );
}
