// The side menu: who's signed in, then My Account, Explore, Help & Settings
// and About, with Log out and the app version at the bottom.
//
// On short screens or with large text the profile and Log out scroll with
// the list instead of staying pinned, so the menu never runs out of room.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../../state/plan_store.dart';
import '../change_pack/plan_screen.dart';
import '../widgets/widgets.dart';
import 'account_statement_screen.dart';
import '../setup_box/setup_box_screens.dart';
import 'home_screen.dart';
import 'language_screen.dart';
import 'support_screen.dart';
import 'my_invoices_screen.dart';
import 'profile_screen.dart';

/// Shown at the bottom of the menu. Keep in step with pubspec.yaml.
const appVersion = '0.1.0';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = math.min(340.0, mq.size.width * 0.84);
    final pin = mq.size.height >= 560 && mq.textScaler.scale(10) <= 13;
    final sub = context.watch<AppStore>().subscriber;
    final nav = Navigator.of(context);

    // Close the menu first, then act.
    void go(Widget screen) {
      nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => screen));
    }

    void soon(String what) {
      nav.pop();
      comingSoon(context, what);
    }

    void myPack() {
      final c = context.read<AppStore>().connection;
      if (c != null) context.read<PlanStore>().open(c);
      go(const PlanScreen(readOnly: true));
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.sm, S.lg),
      child: Row(children: [
        Avatar(initials: sub?.initials ?? '', photo: sub?.photo, size: 52),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub?.name ?? '', style: T.title.copyWith(fontSize: 19)),
            if (sub != null) Text('+91 ${sub.mobilePretty}', style: T.caption.copyWith(fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: 'Close menu', onPressed: nav.pop, icon: const Icon(Icons.close_sharp, color: C.ink)),
      ]),
    );

    final items = <Widget>[
      const _Section('MY ACCOUNT'),
      _Item(Icons.person_outline_sharp, 'My Profile', C.brand, 'Name, number, photo', () => go(const ProfileScreen())),
      _Item(Icons.layers_outlined, 'My Existing Pack', C.brand, 'See what is in your plan', myPack),
      _Item(Icons.summarize_outlined, 'Account Statement', C.brand, 'Recharges and deductions', () => go(const AccountStatementScreen())),
      _Item(Icons.receipt_outlined, 'My Invoices', C.brand, 'Download your bills', () => go(const MyInvoicesScreen())),
      const _Section('EXPLORE'),
      _Item(Icons.router_outlined, 'New Setup Box', C.violet, 'Add another connection', () => go(const NewSetupBoxScreen())),
      _Item(Icons.auto_awesome_outlined, 'Discover Content', C.violet, 'Shows picked for you', () => soon('Discover Content')),
      _Item(Icons.smart_display_outlined, 'VZY Television', C.violet, 'Watch on the go', () => soon('VZY Television')),
      const _Section('HELP & SETTINGS'),
      _Item(Icons.note_add_outlined, 'Issue Tracker', C.teal, 'Track your requests', () => soon('Issue Tracker')),
      _Item(Icons.headset_mic_outlined, 'Contact Customer Support', C.teal, 'Call or chat with us', () => go(const ContactSupportScreen())),
      _Item(Icons.language_sharp, 'Choose Language', C.teal, 'App language', () => go(const LanguageScreen())),
      _Item(Icons.star_outline_sharp, 'Rate Us', C.teal, 'Tell us how we are doing', () => soon('Rate Us')),
      const _Section('ABOUT'),
      _Link('Consumer Corner', () => soon('Consumer Corner')),
      _Link('Privacy Policy', () => soon('Privacy Policy')),
      _Link('Regulatory Information', () => soon('Regulatory Information')),
      const SizedBox(height: S.lg),
    ];

    final footer = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Divider(height: 1, color: C.line),
      Semantics(
        container: true,
        button: true,
        label: 'Log out',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => soon('Log out'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.sm),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: C.brand)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_sharp, size: 20, color: C.brand),
                const SizedBox(width: S.sm),
                Text('Log out', style: T.item.copyWith(fontSize: 15, color: C.brand)),
              ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg + mq.padding.bottom),
        child: Text('App version $appVersion', style: T.caption),
      ),
    ]);

    return Drawer(
      width: width,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(side: BorderSide(color: C.lineStrong)),
      child: SafeArea(
        bottom: false,
        child: pin
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                header,
                const Divider(height: 1, indent: S.page, endIndent: S.page, color: C.line),
                Expanded(child: ListView(padding: EdgeInsets.zero, children: items)),
                footer,
              ])
            : ListView(padding: EdgeInsets.zero, children: [
                header,
                const Divider(height: 1, indent: S.page, endIndent: S.page, color: C.line),
                ...items,
                footer,
              ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, S.xs),
        child: Semantics(
          header: true,
          child: Row(children: [
            Container(width: 3, height: 12, color: C.brand),
            const SizedBox(width: S.sm),
            Text(title, style: T.overline.copyWith(fontSize: 11.5)),
            const SizedBox(width: S.sm),
            const Expanded(child: Divider(height: 1, color: C.line)),
          ]),
        ),
      );
}

/// A menu row: tinted square icon tile, name, short hint, chevron.
class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.tint, this.hint, this.onTap);

  final IconData icon;
  final String label;
  final Color tint;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.page, 8, S.md, 8),
              child: Row(children: [
                SizedBox(width: 40, height: 40, child: Icon(icon, size: 24, color: C.ink)),
                const SizedBox(width: S.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: T.body.copyWith(fontSize: 15, color: C.ink, fontWeight: FontWeight.w700)),
                    Text(hint, style: T.caption.copyWith(fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_right_sharp, color: C.faint),
              ]),
            ),
          ),
        ),
      );
}

/// A plain text link (the About section).
class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        link: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.page, vertical: 11),
              child: Text(label, style: T.body.copyWith(fontSize: 15, color: C.inkSoft)),
            ),
          ),
        ),
      );
}
