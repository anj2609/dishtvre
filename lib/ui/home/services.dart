// Every service, in one list for Home and All services, so both show the
// same names, icons, order and destinations. Home shows the first three of
// each group (the ones used most); All services shows them all.

import 'package:flutter/material.dart';

import '../add_remove/add_remove_screen.dart';
import '../change_pack/change_pack_screen.dart';
import '../hd/upgrade_hd_screens.dart';
import '../ott/add_ott_screen.dart';
import '../recharge/autopay_screen.dart';
import '../recharge/friends_family_screen.dart';
import '../recharge/pay_later_screen.dart';
import '../recharge/recharge_screen.dart';
import '../vacation/vacation_mode_screen.dart';
import 'account_statement_screen.dart';
import 'bills_queries_screen.dart';
import 'home_screen.dart' show comingSoon;
import 'profile_screen.dart';
import 'restore_signal_screen.dart';
import 'support_screen.dart';
import 'tv_error_screen.dart';
import 'update_mobile_screen.dart';

typedef Service = (IconData, String, VoidCallback);

/// The groups' names, in order.
const serviceGroupNames = ['Packs & OTT', 'Recharge & Offers', 'Account & Support'];

/// The services in each group, in [serviceGroupNames] order. [open] pushes a
/// screen; [myPack] opens the selected TV's plan.
List<List<Service>> serviceGroups(BuildContext context, {required void Function(Widget) open, required VoidCallback myPack}) {
  void soon(String what) => comingSoon(context, what);
  return [
    [
      (Icons.live_tv_sharp, 'My Pack', myPack),
      (Icons.add_to_queue_sharp, 'Add/Remove Channel', () => open(const AddRemoveScreen())),
      (Icons.layers_sharp, 'Change Pack', () => open(const ChangePackScreen())),
      (Icons.smart_display_sharp, 'Add OTT', () => open(const AddOttScreen())),
      (Icons.hd_outlined, 'Upgrade to HD', () => open(const HdCheckScreen())),
      (Icons.list_alt_sharp, 'Channel Guide', () => soon('Channel Guide')),
      (Icons.search_sharp, 'Channel No. Finder', () => soon('Channel No. Finder')),
    ],
    [
      (Icons.currency_rupee_sharp, 'Recharge', () => open(const RechargeScreen())),
      (Icons.receipt_long_sharp, 'Account Statement', () => open(const AccountStatementScreen())),
      (Icons.local_offer_outlined, 'Offers', () => soon('Offers')),
      (Icons.event_repeat_sharp, 'Auto Pay', () => open(const AutoPayScreen())),
      (Icons.more_time_sharp, 'Pay Later', () => open(const PayLaterScreen())),
      (Icons.emoji_events_outlined, 'Loyalty', () => soon('Loyalty')),
      (Icons.luggage_outlined, 'Vacation Mode', () => open(const VacationModeScreen())),
      (Icons.people_alt_outlined, 'Recharge for Friends & Family', () => open(const FriendsFamilyScreen())),
    ],
    [
      (Icons.person_outline_sharp, 'My Account', () => open(const ProfileScreen())),
      (Icons.request_quote_outlined, 'Bills & Queries', () => open(const BillsQueriesScreen())),
      (Icons.engineering_outlined, 'Request Technician', () => open(const ContactSupportScreen())),
      (Icons.phonelink_ring_sharp, 'Update Mobile No.', () => open(const UpdateMobileScreen())),
      (Icons.troubleshoot_sharp, 'Troubleshoot', () => soon('Troubleshoot')),
      (Icons.inventory_2_outlined, 'Orders & Requests', () => soon('Orders & Requests')),
      (Icons.wifi_tethering_error_sharp, 'Restore Signal', () => open(const RestoreSignalScreen())),
      (Icons.all_inclusive_sharp, 'Activate Always On', () => soon('Activate Always On')),
      (Icons.tv_off_outlined, 'Resolve on TV Error', () => open(const TvErrorScreen())),
    ],
  ];
}
