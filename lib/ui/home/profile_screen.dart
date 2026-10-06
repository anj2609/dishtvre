// Profile: who the account belongs to, how to reach them, their TVs, and the
// warranty on each TV's equipment. Edit Profile sits at the bottom.
//
// Quiet like Home: dark panels without outlines, white line icons, grey
// labels, and orange only for the selected TV and actions. Colour for status
// only where it means something (TV state, warranty left or expired).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../widgets/widgets.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// The TV whose warranty is shown. Local to this screen, so browsing
  /// warranties doesn't change the TV selected on Home.
  String? _vc;

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static int _monthsBetween(DateTime a, DateTime b) => (b.year - a.year) * 12 + b.month - a.month - (b.day < a.day ? 1 : 0);

  static String _span(int months) {
    final y = months ~/ 12, m = months % 12;
    return [if (y > 0) '$y yr', if (m > 0) '$m mo'].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final sub = app.subscriber;
    final tvs = app.connections;
    final c = tvs.where((x) => x.vc == _vc).firstOrNull ?? app.connection;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Profile'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xxl),
              children: [
                if (sub != null) _identity(sub, tvs),
                if (sub != null) ...[
                  const _SectionTitle('CONTACT DETAILS'),
                  _Panel(children: [
                    _InfoRow(
                      icon: Icons.call_outlined,
                      label: 'MOBILE NUMBER',
                      value: '+91 ${sub.mobilePretty}',
                      note: 'Used for OTP and alerts',
                    ),
                    _InfoRow(
                      icon: Icons.mail_outline_sharp,
                      label: 'EMAIL',
                      value: sub.email.isEmpty ? 'Not added' : sub.email,
                      note: 'Bills and statements are sent here',
                    ),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'INSTALLATION ADDRESS',
                      value: sub.address.isEmpty ? 'Not added' : sub.address.oneLine,
                    ),
                  ]),
                ],
                if (tvs.isNotEmpty) ...[
                  _SectionTitle('YOUR TVs', trailing: '${tvs.length} ${tvs.length == 1 ? 'connection' : 'connections'}'),
                  _Panel(children: [for (final t in tvs) _tvRow(t, selected: t.vc == c?.vc)]),
                ],
                if (c != null) ...[
                  _SectionTitle('WARRANTY', trailing: c.label),
                  FutureBuilder<Warranty>(
                    future: app.warrantyOf(c.vc),
                    builder: (context, snap) {
                      final w = snap.data;
                      if (w == null) return const Skeleton(height: 220);
                      return _warranty(w);
                    },
                  ),
                ],
              ],
            ),
          ),
          BottomBar(
              child: PrimaryButton(
            label: 'Edit Profile',
            icon: Icons.edit_outlined,
            onTap: sub == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          )),
        ]),
      ),
    );
  }

  // Avatar, name and role, then a strip of key facts.
  Widget _identity(Subscriber sub, List<Connection> tvs) {
    final active = tvs.where((t) => t.status == ConnectionStatus.active).length;
    final facts = <(String, String)>[
      ('Customer ID', '${sub.smsId}'),
      if (sub.memberSince != null) ('Member since', '${sub.memberSince!.year}'),
      ('Active TVs', '$active of ${tvs.length}'),
    ];
    return Container(
      color: C.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, S.lg),
          child: Row(children: [
            Avatar(initials: sub.initials, photo: sub.photo, size: 68),
            const SizedBox(width: S.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sub.name, style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.verified_user_outlined, size: 15, color: C.muted),
                  const SizedBox(width: 5),
                  Flexible(child: Text(sub.role, style: T.caption.copyWith(fontSize: 13, color: C.inkSoft))),
                ]),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: C.line, indent: S.lg, endIndent: S.lg),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, f) in facts.indexed) ...[
              if (i > 0) Padding(padding: EdgeInsets.symmetric(vertical: S.md), child: VerticalDivider(width: 1, thickness: 1, color: C.line)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: S.md, horizontal: S.sm),
                  child: Column(children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(f.$2, maxLines: 1, style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 3),
                    Text(f.$1, textAlign: TextAlign.center, style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _tvRow(Connection t, {required bool selected}) {
    final (statusText, statusColor) = switch (t.status) {
      ConnectionStatus.active => ('Active', C.success),
      ConnectionStatus.vacation => ('On vacation', C.vacation),
      ConnectionStatus.deactivated => ('Stopped', C.muted),
    };
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${t.label}, VC ${t.vcPretty}, $statusText${selected ? ', showing its warranty' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => setState(() => _vc = t.vc),
          child: Container(
            padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: selected ? C.brand : Colors.transparent, width: 3))),
            child: Row(children: [
              SizedBox(width: 28, child: Icon(Icons.tv_sharp, size: 22, color: C.ink)),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.label, style: _valueStyle),
                  const SizedBox(height: 2),
                  Text(['VC ${t.vcPretty}', if (t.isMultiTv) 'Multi TV', t.isHd ? 'HD' : 'SD'].join('  ·  '), style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                ]),
              ),
              const SizedBox(width: S.sm),
              Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              Text(statusText, style: T.caption.copyWith(fontSize: 12, color: C.inkSoft)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _warranty(Warranty w) {
    final now = DateTime.now();
    final covered = w.items.where((i) => i.activeOn(now)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Panel(children: [
        for (final i in w.items) _warrantyRow(i, w.installedOn, now),
      ]),
      const SizedBox(height: S.md),
      Row(children: [
        Icon(Icons.info_outline_sharp, size: 15, color: C.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text('${w.kind}  ·  Installed ${_date(w.installedOn)}  ·  $covered of ${w.items.length} parts covered',
              style: T.caption.copyWith(fontSize: 12, color: C.muted)),
        ),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => comingSoon(context, 'Warranty claims'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 0, vertical: S.sm), foregroundColor: C.brand),
          icon: const BrandShade(child: Icon(Icons.build_outlined, size: 17)),
          label: BrandShade(child: Text('Raise a warranty claim', style: T.label.copyWith(color: C.brand))),
        ),
      ),
    ]);
  }

  Widget _warrantyRow(WarrantyItem item, DateTime installed, DateTime now) {
    final active = item.activeOn(now);
    final icon = switch (item.part) {
      'Set-top box' => Icons.router_outlined,
      'Remote control' => Icons.settings_remote_outlined,
      _ => Icons.satellite_alt_outlined,
    };
    final title = [item.part, if (item.model != null) item.model!].join('  ·  ');
    final total = _monthsBetween(installed, item.until).clamp(1, 1200);
    final left = _monthsBetween(now, item.until);
    final share = active ? (left / total).clamp(0.0, 1.0) : 0.0;
    final low = active && share < 0.15;
    final barColor = low ? C.warning : C.success;
    final when = active ? 'Covered till ${_date(item.until)}' : 'Ended ${_date(item.until)}';
    final caption = active
        ? (left < 1 ? 'Less than a month left' : '${_span(left)} left')
        : 'Expired ${_span(_monthsBetween(item.until, now)).isEmpty ? 'this month' : '${_span(_monthsBetween(item.until, now))} ago'}';

    return Semantics(
      container: true,
      label: '$title. $when. $caption',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _IconBox(icon),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: T.caption.copyWith(fontSize: 12, color: C.muted))),
                  const SizedBox(width: S.sm),
                  // Status as plain coloured text: green while covered, amber once ended.
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: active ? C.success : C.warning, shape: BoxShape.circle)),
                  Text(active ? 'Active' : 'Expired', style: T.caption.copyWith(fontSize: 12, color: C.inkSoft)),
                ]),
                const SizedBox(height: 4),
                Text(when, style: _valueStyle),
                const SizedBox(height: S.sm),
                // Coverage left: a flat bar, full at installation, empty at expiry.
                Container(
                  height: 4,
                  color: C.line,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: share, child: Container(color: barColor)),
                ),
                const SizedBox(height: 6),
                Text(caption, style: T.caption.copyWith(fontSize: 12, color: active ? (low ? C.warning : C.inkSoft) : C.warning)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The one size for every tile's main text on this page.
TextStyle get _valueStyle => T.body.copyWith(fontSize: 13.5, height: 1.35, color: C.ink, fontWeight: FontWeight.w600);

/// Section heading: small grey text, and optional text on the right.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: S.xxl, bottom: S.sm + 2),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(_sentence(text), style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700)))),
          if (trailing != null)
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: Text(trailing!, textAlign: TextAlign.end, style: T.caption.copyWith(fontSize: 12, color: C.faint))),
            ),
        ]),
      );

  static String _sentence(String t) => t.isEmpty ? t : t[0] + t.substring(1).toLowerCase().replaceAll('tvs', 'TVs');
}

/// A quiet panel (no outline) whose rows are split by thin, inset lines.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        color: C.surface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: C.line, indent: 54),
            c,
          ],
        ]),
      );
}

/// A white line icon beside each detail, no box.
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(width: 28, height: 28, child: Icon(icon, size: 21, color: C.ink));
}
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.note});

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$label: $value',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _IconBox(icon),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label[0] + label.substring(1).toLowerCase(), style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  const SizedBox(height: 3),
                  Text(value, style: _valueStyle),
                  if (note != null) ...[const SizedBox(height: 2), Text(note!, style: T.caption.copyWith(fontSize: 11.5, color: C.faint))],
                ]),
              ),
            ]),
          ),
        ),
      );
}
