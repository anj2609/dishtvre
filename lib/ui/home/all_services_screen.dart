// Every service, grouped into Packs & OTT, Recharge & Offers and Account &
// Support, as a grid of icon tiles.
//
// The grid is responsive: three columns on a normal phone, fewer as the
// screen narrows or the text grows, and a single list when even two won't
// fit. Labels only ever wrap between words.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/plan_screen.dart';
import '../widgets/widgets.dart';
import 'services.dart';

enum _Group { packs, recharge, account }


class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key, this.initialTab = 0});

  /// Which group opens first: 0 Packs & OTT, 1 Recharge & Offers,
  /// 2 Account & Support.
  final int initialTab;

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  late _Group _g =
      _Group.values[widget.initialTab.clamp(0, _Group.values.length - 1)];

  void _open(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  void _myPack() {
    final c = context.read<AppStore>().connection;
    if (c != null) context.read<PlanStore>().open(c);
    _open(const PlanScreen(readOnly: true));
  }

  @override
  Widget build(BuildContext context) {
    final list = serviceGroups(context, open: _open, myPack: _myPack)[_g.index];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(
              title: 'All services',
              subtitle: 'Everything you can do with DishTV'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.page),
            child: Segmented<_Group>(
              height: 42,
              options: const [
                (_Group.packs, 'Packs & OTT'),
                (_Group.recharge, 'Recharge & Offers'),
                (_Group.account, 'Account & Support')
              ],
              value: _g,
              onChanged: (g) => setState(() => _g = g),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              // Keep the grid at the top while switching groups.
              layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current]),
              child: SingleChildScrollView(
                key: ValueKey(_g),
                padding: EdgeInsets.fromLTRB(S.page, S.lg, S.page,
                    S.xxl + MediaQuery.paddingOf(context).bottom),
                child: ServiceGrid(services: list),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class ServiceGrid extends StatelessWidget {
  const ServiceGrid({required this.services});

  final List<Service> services;

  static const _gap = S.sm;
  static const _pad = 8.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = T.label.copyWith(
        fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.25, color: C.inkSoft);
    return LayoutBuilder(builder: (context, box) {
      // Columns: as many as fit at ~88px each (scaled with the text), up to 3.
      final minTile = 88 * scaler.scale(10) / 10;
      final cols =
          ((box.maxWidth + _gap) / (minTile + _gap)).floor().clamp(1, 3);
      final tileW = (box.maxWidth - _gap * (cols - 1)) / cols;
      final row = cols == 1;

      // Labels wrap only between words: if the longest word is wider than a
      // tile, shrink the label font just enough for it to fit.
      final textW = row ? tileW - 16 - 30 - 12 - 16 : tileW - _pad * 2;
      var widest = 0.0;
      for (final s in services) {
        for (final word in s.$2.split(' ')) {
          final tp = TextPainter(
              text: TextSpan(text: word, style: base),
              textScaler: scaler,
              textDirection: TextDirection.ltr,
              maxLines: 1)
            ..layout();
          widest = math.max(widest, tp.width);
          tp.dispose();
        }
      }
      final style = widest > textW
          ? base.copyWith(fontSize: base.fontSize! * textW / widest * 0.97)
          : base;

      // Every label gets the height of the tallest one, so all rows of the
      // grid are the same height (a one-line row isn't shorter).
      var labelH = 0.0;
      if (!row) {
        for (final s in services) {
          final tp = TextPainter(
              text: TextSpan(text: s.$2, style: style),
              textScaler: scaler,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr)
            ..layout(maxWidth: textW);
          labelH = math.max(labelH, tp.height);
          tp.dispose();
        }
      }

      final rows = <Widget>[];
      for (var i = 0; i < services.length; i += cols) {
        final chunk = services.sublist(i, math.min(i + cols, services.length));
        rows.add(Padding(
          padding:
              EdgeInsets.only(bottom: i + cols < services.length ? _gap : 0),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: _gap),
                Expanded(
                    child: j < chunk.length
                        ? _Tile(service: chunk[j], style: style, row: row, labelHeight: labelH)
                        : const SizedBox()),
              ],
            ]),
          ),
        ));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// One service: a white icon over its name on a quiet tile (or an
/// icon beside the name when the grid collapses to a single column).
class _Tile extends StatelessWidget {
  const _Tile({required this.service, required this.style, required this.row, this.labelHeight = 0});

  final Service service;
  final TextStyle style;
  final bool row;

  /// Room for the label in the grid, the same on every tile.
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final (icon, label, onTap) = service;
    final iconW = Icon(icon, size: 26, color: C.ink);
    final text = Text(label,
        textAlign: row ? TextAlign.start : TextAlign.center, style: style);
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: ExcludeSemantics(
        // A quiet tile, no outline, like the services on Home.
        child: Material(
          color: C.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: row
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                  : const EdgeInsets.fromLTRB(
                      ServiceGrid._pad, 20, ServiceGrid._pad, 18),
              child: row
                  ? Row(children: [
                      iconW,
                      const SizedBox(width: 12),
                      Expanded(child: text)
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          iconW,
                          const SizedBox(height: 10),
                          SizedBox(height: labelHeight, child: Align(alignment: Alignment.topCenter, child: text)),
                        ]),
            ),
          ),
        ),
      ),
    );
  }
}
