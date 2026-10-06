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
import '../change_pack/change_pack_screen.dart';
import '../hd/upgrade_hd_screens.dart';
import '../ott/add_ott_screen.dart';
import '../change_pack/plan_screen.dart';
import '../add_remove/add_remove_screen.dart';
import '../widgets/widgets.dart';
import '../recharge/autopay_screen.dart';
import '../recharge/friends_family_screen.dart';
import '../recharge/pay_later_screen.dart';
import '../recharge/recharge_screen.dart';
import '../vacation/vacation_mode_screen.dart';
import 'account_statement_screen.dart';
import 'bills_queries_screen.dart';
import 'update_mobile_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'restore_signal_screen.dart';
import 'tv_error_screen.dart';

enum _Group { packs, recharge, account }

typedef _Service = (IconData, String, VoidCallback);

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

  void _soon(String what) => comingSoon(context, what);

  Map<_Group, List<_Service>> get _services => {
        _Group.packs: [
          (Icons.live_tv_sharp, 'My Pack', _myPack),
          (
            Icons.add_to_queue_sharp,
            'Add/Remove Channel',
            () => _open(const AddRemoveScreen())
          ),
          (
            Icons.layers_sharp,
            'Change Pack',
            () => _open(const ChangePackScreen())
          ),
          (Icons.smart_display_sharp, 'Add OTT', () => _open(const AddOttScreen())),
          (
            Icons.hd_outlined,
            'Upgrade to HD',
            () => _open(const HdCheckScreen())
          ),
          (Icons.list_alt_sharp, 'Channel Guide', () => _soon('Channel Guide')),
          (
            Icons.search_sharp,
            'Channel No. Finder',
            () => _soon('Channel No. Finder')
          ),
        ],
        _Group.recharge: [
          (Icons.currency_rupee_sharp, 'Recharge', () => _open(const RechargeScreen())),
          (Icons.event_repeat_sharp, 'Autopay', () => _open(const AutoPayScreen())),
          (
            Icons.more_time_sharp,
            'Pay Later',
            () => _open(const PayLaterScreen())
          ),
          (
            Icons.receipt_long_sharp,
            'Account Statement',
            () => _open(const AccountStatementScreen())
          ),
          (Icons.local_offer_outlined, 'Offers', () => _soon('Offers')),
          (Icons.emoji_events_outlined, 'Loyalty', () => _soon('Loyalty')),
          (
            Icons.luggage_outlined,
            'Pause Connection',
            () => _open(const VacationModeScreen())
          ),
          (
            Icons.people_alt_outlined,
            'Recharge for Friends & Family',
            () => _open(const FriendsFamilyScreen())
          ),
        ],
        _Group.account: [
          (
            Icons.person_outline_sharp,
            'My Account',
            () => _open(const ProfileScreen())
          ),
          (
            Icons.phonelink_ring_sharp,
            'Update Mobile No.',
            () => _open(const UpdateMobileScreen())
          ),
          (
            Icons.troubleshoot_sharp,
            'Troubleshoot',
            () => _soon('Troubleshoot')
          ),
          (
            Icons.request_quote_outlined,
            'Bills & Queries',
            () => _open(const BillsQueriesScreen())
          ),
          (
            Icons.inventory_2_outlined,
            'Orders & Requests',
            () => _soon('Orders & Requests')
          ),
          (
            Icons.wifi_tethering_error_sharp,
            'Signal Issue',
            () => _open(const RestoreSignalScreen())
          ),
          (
            Icons.all_inclusive_sharp,
            'Activate Always On',
            () => _soon('Activate Always On')
          ),
          (
            Icons.tv_off_outlined,
            'Resolve on TV Error',
            () => _open(const TvErrorScreen())
          ),
          (
            Icons.engineering_outlined,
            'Request Technician',
            () => _soon('Request Technician')
          ),
        ],
      };

  @override
  Widget build(BuildContext context) {
    final list = _services[_g]!;
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
                child: _ServiceGrid(services: list),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services});

  final List<_Service> services;

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
                        ? _Tile(service: chunk[j], style: style, row: row)
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
  const _Tile({required this.service, required this.style, required this.row});

  final _Service service;
  final TextStyle style;
  final bool row;

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
                      _ServiceGrid._pad, 20, _ServiceGrid._pad, 18),
              child: row
                  ? Row(children: [
                      iconW,
                      const SizedBox(width: 12),
                      Expanded(child: text)
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [iconW, const SizedBox(height: 10), text]),
            ),
          ),
        ),
      ),
    );
  }
}
