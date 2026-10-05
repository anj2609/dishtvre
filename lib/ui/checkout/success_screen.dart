// Success: confetti, an animated check, the order ID, the new monthly bill and what
// changed. Done returns Home.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/plan_store.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() {
    context.read<PlanStore>().finish();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.4).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: c,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlanStore>();
    final a = p.applied;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 48, S.page, S.xl),
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.45, curve: Curves.elasticOut)),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: C.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                        0.25,
                        Column(children: [
                          Text('Your plan is updated', textAlign: TextAlign.center, style: T.display),
                          const SizedBox(height: 6),
                          if (p.orderId != null) Text('Order ID ${p.orderId}', style: T.label.copyWith(color: C.muted)),
                        ])),
                    // Receipt style: sections split by thin lines, no boxes or fills.
                    if (a != null) ...[
                      const SizedBox(height: S.xxl),
                      const Divider(height: 1, thickness: 1, color: C.lineStrong),
                      _fade(
                          0.4,
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: S.lg),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('NEW MONTHLY BILL', style: T.overline),
                                  const SizedBox(height: 2),
                                  Text(rupees(a.next), style: T.price.copyWith(fontSize: 26)),
                                ]),
                              ),
                              Text(
                                (a.next - a.previous).abs() < 0.5
                                    ? 'Same as before'
                                    : '${rupees((a.next - a.previous).abs())} ${a.next < a.previous ? 'less' : 'more'} a month',
                                style: T.label.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: a.next <= a.previous ? C.success : C.warning,
                                ),
                              ),
                            ]),
                          )),
                      const Divider(height: 1, thickness: 1, color: C.lineStrong),
                      _fade(
                          0.5,
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: S.lg),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('WHAT CHANGED', style: T.overline),
                              const SizedBox(height: S.sm),
                              if (a.base != null) _line(Icons.swap_horiz_rounded, C.brand, 'Switched to ${a.base!.name}'),
                              for (final i in a.added) _line(Icons.add_rounded, C.success, 'Added ${i.name}', logo: i.logoUrl, name: i.name),
                              for (final i in a.removed) _line(Icons.remove_rounded, C.danger, 'Removed ${i.name}', logo: i.logoUrl, name: i.name),
                            ]),
                          )),
                      const Divider(height: 1, thickness: 1, color: C.lineStrong),
                    ],
                    const SizedBox(height: S.lg),
                    _fade(
                        0.6, Text('Channels update on your TV within a few minutes. Keep the set-top box on.', textAlign: TextAlign.center, style: T.caption)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg),
                child: PrimaryButton(label: 'Done', onTap: _done),
              ),
            ]),
          ),
          const Positioned.fill(child: Confetti()),
        ]),
      ),
    );
  }

  Widget _line(IconData icon, Color c, String text, {String? logo, String name = ''}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: S.sm),
          if (logo != null) ...[ChannelLogo(name: name, url: logo, size: 30), const SizedBox(width: S.sm)],
          Expanded(child: Text(text, style: T.body.copyWith(color: C.ink))),
        ]),
      );
}
