// The side menu: who's signed in, then My Account, Explore, Help & Settings
// and About, with Log out and the app version at the bottom.
//
// On short screens or with large text the profile and Log out scroll with
// the list instead of staying pinned, so the menu never runs out of room.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../app/theme_switch.dart';
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
      padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.sm, S.lg),
      child: Row(children: [
        Avatar(initials: sub?.initials ?? '', photo: sub?.photo, size: 48),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            if (sub != null) Text('+91 ${sub.mobilePretty}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
          ]),
        ),
        IconButton(tooltip: 'Close menu', onPressed: nav.pop, icon: Icon(Icons.close_sharp, color: C.inkSoft, size: 22)),
      ]),
    );

    // Each section is one quiet panel of rows, like the services on Home.
    final items = <Widget>[
      _Group('My account', [
        _Item(Icons.person_outline_sharp, 'My Profile', 'Name, number, photo', () => go(const ProfileScreen())),
        _Item(Icons.layers_outlined, 'My Existing Pack', 'See what is in your plan', myPack),
        _Item(Icons.summarize_outlined, 'Account Statement', 'Recharges and deductions', () => go(const AccountStatementScreen())),
        _Item(Icons.receipt_outlined, 'My Invoices', 'Download your bills', () => go(const MyInvoicesScreen())),
      ]),
      _Group('Explore', [
        _Item(Icons.router_outlined, 'New Setup Box', 'Add another connection', () => go(const NewSetupBoxScreen())),
        _Item(Icons.auto_awesome_outlined, 'Discover Content', 'Shows picked for you', () => soon('Discover Content')),
        _Item(Icons.smart_display_outlined, 'VZY Television', 'Watch on the go', () => soon('VZY Television')),
      ]),
      _Group('Help & settings', [
        _Item(Icons.note_add_outlined, 'Issue Tracker', 'Track your requests', () => soon('Issue Tracker')),
        // Light or dark: the row flips it, and the switch shows which is on.
        _Item(
          lightMode.value ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          'Appearance',
          lightMode.value ? 'Light theme' : 'Dark theme',
          toggleLightMode,
          trailing: const ThemeToggle(),
          toggled: lightMode.value,
        ),
        _Item(Icons.headset_mic_outlined, 'Contact Customer Support', 'Call or chat with us', () => go(const ContactSupportScreen())),
        _Item(Icons.language_sharp, 'Choose Language', 'App language', () => go(const LanguageScreen())),
        _Item(Icons.star_outline_sharp, 'Rate Us', 'Tell us how we are doing', () => soon('Rate Us')),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(S.page, S.xl, S.page, 0),
        child: Text('About', style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
      ),
      const SizedBox(height: S.xs),
      _Link('Consumer Corner', () => soon('Consumer Corner')),
      _Link('Privacy Policy', () => soon('Privacy Policy')),
      _Link('Regulatory Information', () => soon('Regulatory Information')),
      const SizedBox(height: S.lg),
    ];

    final footer = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        container: true,
        button: true,
        label: 'Log out',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.sm),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => soon('Log out'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    BrandShade(child: Icon(Icons.logout_sharp, size: 19, color: C.brand)),
                    const SizedBox(width: S.sm),
                    BrandShade(child: Text('Log out', style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: C.brand))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.xs, S.page, S.lg + mq.padding.bottom),
        child: Text('App version $appVersion', textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 11.5, color: C.faint)),
      ),
    ]);

    return Drawer(
      width: width,
      backgroundColor: C.bg,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.line)),
      child: SafeArea(
        bottom: false,
        child: pin
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                header,
                Expanded(child: ListView(padding: EdgeInsets.zero, children: items)),
                footer,
              ])
            : ListView(padding: EdgeInsets.zero, children: [
                header,
                ...items,
                footer,
              ]),
      ),
    );
  }
}

/// A section: a small grey heading, then its rows straight on the menu, no
/// panel and no lines between them.
class _Group extends StatelessWidget {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(S.page, S.lg, S.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: S.sm),
            child: Semantics(header: true, child: Text(title, style: T.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted))),
          ),
          // Rows sit straight on the menu, no panel behind them.
          Column(children: items),
        ]),
      );
}

/// A menu row: white line icon, name, short grey hint, faint chevron.
class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.hint, this.onTap, {this.trailing, this.toggled});

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  /// Replaces the chevron (e.g. a switch).
  final Widget? trailing;

  /// For a row that switches something on and off.
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        toggled: toggled,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.md, 13, S.sm, 13),
              child: Row(children: [
                SizedBox(width: 28, child: Icon(icon, size: 22, color: C.ink)),
                const SizedBox(width: S.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink)),
                    const SizedBox(height: 2),
                    Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  ]),
                ),
                trailing ?? Icon(Icons.chevron_right_sharp, color: C.faint, size: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: S.page, vertical: 9),
              child: Text(label, style: T.body.copyWith(fontSize: 13.5, color: C.inkSoft)),
            ),
          ),
        ),
      );
}
