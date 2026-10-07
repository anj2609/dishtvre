// A connection on Home: name, VC, the two figures that matter (monthly
// recharge, when service stops) and Recharge now, on a deep gradient for its
// state: orange active, blue on vacation, grey deactivated.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../widgets/showtime.dart' show GlossSweep;

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
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${m[d.month - 1]}';
}

/// Gradient stops for a card: a brighter shade top-left, the card colour,
/// and a deep shade bottom-right.
List<Color> cardGradientOf(ConnectionStatus st) => switch (st) {
      // A touch calmer than the brand orange, so the white Recharge button
      // is the brightest thing on the card.
      ConnectionStatus.active => const [
          Color(0xFFE86A38),
          Color(0xFFC9542A),
          Color(0xFF94401F)
        ],
      ConnectionStatus.vacation => const [
          Color(0xFF4C7BDA),
          Color(0xFF2E58B3),
          Color(0xFF1A3270)
        ],
      ConnectionStatus.deactivated => const [
          Color(0xFF5B5B68),
          Color(0xFF3E3E49),
          Color(0xFF26262E)
        ],
    };

class ConnectionCard extends StatelessWidget {
  const ConnectionCard(
      {super.key,
      required this.c,
      required this.onRecharge,
      this.compact = false});

  final Connection c;
  final VoidCallback onRecharge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = cardColorOf(c.status);
    final days = c.daysLeft(DateTime.now());
    final pillText = switch (c.status) {
      ConnectionStatus.vacation => 'On vacation',
      ConnectionStatus.deactivated => 'Service stopped',
      _ when c.vacationBooked => 'Vacation booked',
      _ when days <= 0 => 'Stops today',
      _ => '$days ${days == 1 ? 'day' : 'days'} left',
    };
    const soft = Color(0xD9FFFFFF);
    final small = T.caption.copyWith(fontSize: 11.5, height: 1.25, color: soft);

    // At accessibility text sizes the parts stack instead of sitting side
    // by side, so names, numbers and labels wrap rather than truncate.
    final big = MediaQuery.textScalerOf(context).scale(10) > 14;
    final dotColor = switch (c.status) {
      ConnectionStatus.active when c.vacationBooked => const Color(0xFFBBD2FF),
      // Amber once it's close to stopping (same rule as Recharge).
      ConnectionStatus.active when days <= 5 => const Color(0xFFFFC56B),
      ConnectionStatus.active => const Color(0xFF7CF2B0),
      ConnectionStatus.vacation => const Color(0xFFBBD2FF),
      ConnectionStatus.deactivated => const Color(0xFFFF8C8C),
    };
    // Status: a live dot and the text.
    final status = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(right: 5, top: 5),
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      Flexible(
        child: Text(pillText,
            textAlign: big ? TextAlign.left : TextAlign.right,
            maxLines: big ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: T.caption.copyWith(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: const Color(0xE6FFFFFF))),
      ),
    ]);
    final name = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(c.label,
          maxLines: big ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: T.item.copyWith(fontSize: 16, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 2),
      // VC and Multi TV share one quiet line (two when the text is large).
      // With large type: the VC on a line of its own, never split mid-number.
      Text(
          big
              ? 'VC\u00A0${c.vcPretty.replaceAll(' ', '\u00A0')}${c.isMultiTv ? '\nMulti TV' : ''}'
              : ['VC ${c.vcPretty}', if (c.isMultiTv) 'Multi TV'].join('  ·  '),
          maxLines: big ? null : 1,
          overflow: big ? null : TextOverflow.ellipsis,
          style: small),
      if (big) ...[const SizedBox(height: 6), status],
    ]);
    final recharge = _figure('Monthly recharge', rupees(c.monthlyRecharge), 'Balance ${rupees(c.balance)}', small, big);
    final stops = _figure(
      c.status == ConnectionStatus.deactivated ? 'Service stopped' : 'Service stops',
      fmtDate(c.switchOffDate),
      // The vacation dates, else the lock-in.
      c.status == ConnectionStatus.vacation && c.resumeOn != null
          ? 'Back on ${fmtDate(c.resumeOn!)}'
          : c.vacationBooked
              ? 'Pauses ${fmtDate(c.pauseFrom!)}'
              : (c.lockInUntil != null ? 'Lock-in till ${fmtDate(c.lockInUntil!)}' : null),
      small,
      big,
    );

    final content = Padding(
      padding: EdgeInsets.fromLTRB(18, compact ? 14 : 18, 18, 18),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.tv_sharp, color: Colors.white, size: 22)),
              const SizedBox(width: 10),
              Expanded(child: name),
              if (!big) ...[
                const SizedBox(width: S.sm),
                // Flush right and level with the TV name.
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140), child: Padding(padding: const EdgeInsets.only(top: 1), child: status)),
              ],
            ]),
            const SizedBox(height: 22),
            if (big)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                recharge,
                Container(height: 1, color: const Color(0x40FFFFFF), margin: const EdgeInsets.symmetric(vertical: S.md)),
                stops,
              ])
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: recharge),
                Container(width: 1, height: 46, color: const Color(0x40FFFFFF), margin: const EdgeInsets.symmetric(horizontal: S.lg)),
                Expanded(child: stops),
              ]),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: onRecharge,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: S.md, vertical: 12),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                                c.status == ConnectionStatus.deactivated
                                    ? 'Recharge to restart'
                                    : 'Recharge now',
                                textAlign: TextAlign.center,
                                style: T.label.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: fill)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_sharp,
                              color: fill, size: 17),
                        ]),
                  ),
                ),
              ),
            ),
          ]),
    );

    // The colour: a bright shade top-left melting into a deep one
    // bottom-right, with a soft glow in the top-left corner.
    final g = cardGradientOf(c.status);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: g,
            stops: const [0, 0.45, 1]),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: const Alignment(-0.9, -1.1),
                  radius: 1.1,
                  colors: [
                    g[0].withValues(alpha: 0.35),
                    g[0].withValues(alpha: 0)
                  ]),
            ),
          ),
        ),
        const Positioned.fill(child: GlossSweep()),
        content,
      ]),
    );
  }

  Widget _figure(String label, String value, String? note, TextStyle small, bool big) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: small),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: T.price
                  .copyWith(fontSize: 20, height: 1.2, color: Colors.white)),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note,
              maxLines: big ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(fontSize: 11)),
        ],
      ]);
}
