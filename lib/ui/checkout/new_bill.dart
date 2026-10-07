// The new monthly bill under a pending change, as one figure everywhere:
// the same server quote Review shows. While a change is being priced the
// previous figure stays, faded, so the number never jumps to a guess.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../state/plan_store.dart';

class NewBill extends StatelessWidget {
  const NewBill(this.plan, {super.key, required this.style, this.suffix = '/mo'});

  final PlanStore plan;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final busy = plan.pricing;
    return Semantics(
      label: busy ? 'Working out your new bill' : 'New bill ${rupees(plan.newBill)} a month',
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: busy ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: Text('${rupees(plan.newBill)}$suffix', style: style),
      ),
    );
  }
}

/// "New bill ₹1,174/month" in a line of running text, or what's happening
/// while it's priced.
String newBillLine(PlanStore plan, {String suffix = '/month'}) =>
    plan.pricing ? 'Working out your new bill…' : 'New bill ${rupees(plan.newBill)}$suffix';
