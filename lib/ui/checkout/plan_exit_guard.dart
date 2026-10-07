// Wraps the first screen of a flow that edits the plan (Change Pack,
// Add/Remove Channel, Add OTT). Leaving it with changes not applied asks
// first, and leaving clears them, so they can't turn up later in another
// flow's Review. When one of these flows opens another (Add/Remove → Change
// pack), only the outermost one asks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/plan_store.dart';
import '../widgets/widgets.dart';

class PlanExitGuard extends StatefulWidget {
  const PlanExitGuard({super.key, required this.child});
  final Widget child;

  @override
  State<PlanExitGuard> createState() => _PlanExitGuardState();
}

class _PlanExitGuardState extends State<PlanExitGuard> {
  /// Guards on screen, outermost first.
  static final _open = <_PlanExitGuardState>[];

  bool get _outermost => _open.isNotEmpty && identical(_open.first, this);

  @override
  void initState() {
    super.initState();
    _open.add(this);
  }

  @override
  void dispose() {
    _open.remove(this);
    super.dispose();
  }

  Future<void> _leave(PlanStore plan) async {
    final nav = Navigator.of(context);
    final n = plan.changeCount;
    final discard = await showSheet<bool>(
      context,
      title: 'Discard your changes?',
      subtitle: 'You have $n ${n == 1 ? 'change' : 'changes'} not applied yet. Leaving removes ${n == 1 ? 'it' : 'them'}.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PrimaryButton(label: 'Keep editing', onTap: () => Navigator.of(ctx).pop(false)),
          const SizedBox(height: S.sm),
          SecondaryButton(label: 'Discard changes', onTap: () => Navigator.of(ctx).pop(true)),
        ]),
      ),
    );
    if (discard != true || !mounted) return;
    HapticFeedback.mediumImpact();
    plan.discard();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanStore>();
    final ask = _outermost && plan.hasChanges && plan.applyState != ApplyState.applying;
    return PopScope(
      canPop: !ask,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(plan);
      },
      child: widget.child,
    );
  }
}
