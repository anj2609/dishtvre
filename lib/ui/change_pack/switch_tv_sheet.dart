// Pick which connection to change. Paused and stopped connections are shown
// (with a lock) but can't be picked, unless [anyTv] is set (e.g. to recharge
// them).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../home/connection_card.dart';
import '../widgets/widgets.dart';

Future<String?> showSwitchTvSheet(BuildContext context,
    {String title = 'Which TV do you want to change?',
    String subtitle = 'Pack changes apply to one connection at a time.',
    bool anyTv = false}) {
  final app = context.read<AppStore>();
  return showSheet<String>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
          S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
      children: [
        for (final c in app.connections) ...[
          _row(ctx, c, selected: c.vc == app.connection?.vc, anyTv: anyTv),
          const SizedBox(height: S.sm + 2),
        ],
      ],
    ),
  );
}

// Each TV is filled with its Home card colour: coral active, blue on
// vacation, grey stopped.
Widget _row(BuildContext ctx, Connection c,
    {required bool selected, bool anyTv = false}) {
  final usable = anyTv || c.status == ConnectionStatus.active;
  final fill = cardColorOf(c.status);
  const soft = Color(0xD9FFFFFF);
  final note = switch (c.status) {
    ConnectionStatus.active =>
      '${c.planName} | ${rupees(c.monthlyRecharge)}/month',
    ConnectionStatus.vacation => anyTv
        ? 'On vacation · ${rupees(c.monthlyRecharge)}/month'
        : 'On vacation. Resume service to change its pack.',
    ConnectionStatus.deactivated => anyTv
        ? 'Service stopped · recharge to restart'
        : 'Service stopped. Recharge to change its pack.',
  };
  return Semantics(
    container: true,
    button: usable,
    selected: selected,
    enabled: usable,
    label: '${c.label}, VC ${c.vcPretty}. $note',
    child: ExcludeSemantics(
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected
                  ? Colors.white
                  : Color.lerp(fill, Colors.white, 0.18)!,
              width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        // The same gradient as the TV's Home card.
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.45, 1],
                colors: cardGradientOf(c.status)),
          ),
          child: InkWell(
            onTap: usable ? () => Navigator.of(ctx).pop(c.vc) : null,
            child: Padding(
              padding: const EdgeInsets.all(S.md + 2),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  child:
                      const Icon(Icons.tv_sharp, color: Colors.white, size: 20),
                ),
                const SizedBox(width: S.md),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.label,
                            style: T.item.copyWith(color: Colors.white)),
                        Text('VC ${c.vcPretty}',
                            style: T.caption.copyWith(color: soft)),
                        const SizedBox(height: 2),
                        Text(note,
                            style: T.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
                if (selected) ...[
                  const SizedBox(width: S.sm),
                  const Icon(Icons.check_circle_sharp, color: Colors.white)
                ],
                if (!usable) ...[
                  const SizedBox(width: S.sm),
                  const Icon(Icons.lock_outline_sharp, color: soft, size: 20)
                ],
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}
