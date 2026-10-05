// A connection on Home: name, VC, the two figures that matter (monthly
// recharge, when service stops) and Recharge now, in a compact card filled
// with a solid colour for its state: coral active, blue on vacation, grey
// deactivated.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

(Color, Color) accentOf(ConnectionStatus s) => switch (s) {
      ConnectionStatus.active => (C.brand, C.brandSoft),
      ConnectionStatus.vacation => (C.vacation, C.vacationSoft),
      ConnectionStatus.deactivated => (C.off, C.offSoft),
    };

/// The solid fill of a connection's card.
Color cardColorOf(ConnectionStatus s) => switch (s) {
      ConnectionStatus.active => const Color(0xFFD9542B),
      ConnectionStatus.vacation => const Color(0xFF2F5FBF),
      ConnectionStatus.deactivated => const Color(0xFF3A3A47),
    };

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.c, required this.onRecharge, this.compact = false});

  final Connection c;
  final VoidCallback onRecharge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = cardColorOf(c.status);
    final days = c.daysLeft(DateTime.now());
    final pillText = switch (c.status) {
      ConnectionStatus.vacation => 'Paused',
      ConnectionStatus.deactivated => 'Service stopped',
      _ when days <= 0 => 'Stops today',
      _ => '$days ${days == 1 ? 'day' : 'days'} left',
    };
    const soft = Color(0xD9FFFFFF);
    final small = T.caption.copyWith(fontSize: 11.5, height: 1.25, color: soft);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: Color.lerp(fill, Colors.white, 0.18)!),
        boxShadow: D.lift,
      ),
      padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: const Icon(Icons.tv_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.label, style: T.item.copyWith(fontSize: 14.5, height: 1.2, color: Colors.white)),
              Text('VC ${c.vcPretty}', style: small),
              if (c.isMultiTv) Text('Multi TV', style: small.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          const SizedBox(width: S.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const Color(0x40000000),
              child: Text(pillText,
                  textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _figure('Monthly recharge', rupees(c.monthlyRecharge), 'Balance ${rupees(c.balance)}', small)),
          Container(width: 1, height: 38, color: const Color(0x40FFFFFF), margin: const EdgeInsets.symmetric(horizontal: S.md)),
          Expanded(
            child: _figure(
              c.status == ConnectionStatus.deactivated ? 'Service stopped' : 'Service stops',
              fmtDate(c.switchOffDate),
              c.lockInUntil != null ? 'Lock-in till ${fmtDate(c.lockInUntil!)}' : c.planName,
              small,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: onRecharge,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: 9),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(c.status == ConnectionStatus.deactivated ? 'Recharge to restart' : 'Recharge now',
                        textAlign: TextAlign.center, style: T.label.copyWith(fontSize: 14, color: fill)),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: fill, size: 17),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _figure(String label, String value, String note, TextStyle small) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: small),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.price.copyWith(fontSize: 18, height: 1.25, color: Colors.white)),
        ),
        Text(note, style: small.copyWith(fontSize: 11)),
      ]);
}
