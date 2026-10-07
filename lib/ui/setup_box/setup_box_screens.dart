// New Setup Box: choose Upgrade to Android, Get a New Connection or Multi TV.
// Upgrade and New Connection end in Review & Pay, where "simulate success /
// failure" decides the outcome. Multi TV verifies a mobile number by OTP.
//
// Colour comes from solid bands and tiles in the Home-card palette, with a
// faint oversized icon as a watermark; no gradients, sharp corners.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';

const _boxPrice = 2999.0;
const _gstRate = 0.18;
const _months = [
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

// Solid colours, same family as the Home cards.
const _orange = Color(0xFFD9552B);
const _violet = Color(0xFF6656E0);
const _teal = Color(0xFF0E9488);
const _blue = Color(0xFF2F5FC4);
const _green = Color(0xFF1F7A55);
const _red = Color(0xFFC2384A);
const _softWhite = Color(0xE6FFFFFF);

/// What is being bought, shared by Review, Pay and Success.
class _Order {
  const _Order(
      {required this.name,
      required this.detail,
      required this.price,
      required this.icon,
      required this.accent,
      required this.successTitle,
      required this.successLine});

  final String name;
  final String detail;
  final double price;
  final IconData icon;
  final Color accent;
  final String successTitle;
  final String successLine;

  double get gst => price * _gstRate;
  double get total => price + gst;
}

/// The card effect for a block: the Home-card orange for orange, the same
/// treatment in its own colour for anything else.
// Like Home: one strong orange block per screen, everything else quiet.
LinearGradient _card(Color c) => G.brand;

Route<T> _route<T>(Widget w) => MaterialPageRoute<T>(builder: (_) => w);

void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

// ---------------------------------------------------------------------------
// Shared pieces

/// A solid colour band with a faint oversized icon behind the content.
class _Band extends StatelessWidget {
  const _Band(
      {required this.color, required this.watermark, required this.child});

  final Color color;
  final IconData watermark;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: _card(color)),
        padding: const EdgeInsets.all(S.lg),
        child: child,
      );
}

/// A section title: bold sentence-case text, no marker or rule. ([color] is
/// kept so callers stay simple; headings are never coloured.)
class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = text.isEmpty ? text : text[0] + text.substring(1).toLowerCase().replaceAll(' tv', ' TV');
    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: Semantics(header: true, child: Text(t, style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
    );
  }
}

/// A little solid label, e.g. "NEW" or "FROM ₹931".
class _Chip extends StatelessWidget {
  const _Chip(this.text, this.fill, {this.color = Colors.white});
  final String text;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(text,
            style: T.overline
                .copyWith(color: color, fontSize: 10.5, letterSpacing: 0.5)),
      );
}

/// A row of steps: a numbered coloured square, then its label.
class _Steps extends StatelessWidget {
  const _Steps(this.steps, this.color);
  final List<(IconData, String, String)> steps;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, s) in steps.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                  width: 18,
                  child: Divider(
                      height: 1, thickness: 1, color: C.lineStrong)),
            ),
          Expanded(
            child: Column(children: [
              SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(s.$1, color: C.ink, size: 24)),
              const SizedBox(height: 6),
              Text(s.$2,
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(s.$3,
                  textAlign: TextAlign.center,
                  style: T.caption.copyWith(fontSize: 11.5, color: C.muted)),
            ]),
          ),
        ],
      ]);
}

/// A roomy row: coloured icon, bold title and a short line under it.
class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.note,
      this.last = false});

  final IconData icon;
  final Color color;
  final String title;
  final String note;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: S.lg),
        decoration: BoxDecoration(
            border:
                last ? null : Border(bottom: BorderSide(color: C.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 32, child: Icon(icon, color: C.ink, size: 22)),
          const SizedBox(width: S.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(note,
                  style: T.caption.copyWith(fontSize: 12.5, height: 1.45, color: C.muted)),
            ]),
          ),
        ]),
      );
}

/// The set-top box (and optionally its remote), drawn from shapes.
class _BoxArt extends StatelessWidget {
  const _BoxArt({this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150 * scale,
        height: 90 * scale,
        child: FittedBox(
          child: SizedBox(
            width: 150,
            height: 90,
            child: Stack(children: [
              Positioned(
                left: 0,
                bottom: 8,
                child: Container(
                  width: 118,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1B1B22),
                      border: Border.all(color: const Color(0xFF4A4A58))),
                  child: Row(children: [
                    const SizedBox(width: 10),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: C.success, shape: BoxShape.circle)),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      Container(
                          margin: const EdgeInsets.only(right: 5),
                          width: 10,
                          height: 2,
                          color: const Color(0xFF4A4A58)),
                  ]),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Container(
                    width: 18,
                    height: 80,
                    decoration: BoxDecoration(
                        color: const Color(0xFF1B1B22),
                        border: Border.all(color: const Color(0xFF4A4A58))),
                    child: Column(children: [
                      const SizedBox(height: 8),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              gradient: G.brand, shape: BoxShape.circle)),
                      const SizedBox(height: 6),
                      for (var i = 0; i < 4; i++)
                        Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            width: 8,
                            height: 4,
                            color: const Color(0xFF4A4A58)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// New Setup Box

class NewSetupBoxScreen extends StatelessWidget {
  const NewSetupBoxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'New Setup Box'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page,
                  S.xxl + MediaQuery.paddingOf(context).bottom),
              children: [
                _Band(
                  color: _orange,
                  watermark: Icons.router_outlined,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Get more from DishTV',
                            style: T.display
                                .copyWith(color: Colors.white, fontSize: 24)),
                        const SizedBox(height: 6),
                        Text(
                            'Upgrade to an Android box, book a new connection or add DishTV to another TV.',
                            style: T.body
                                .copyWith(color: _softWhite, fontSize: 14)),
                        const SizedBox(height: S.lg),
                        Wrap(spacing: S.sm, runSpacing: S.sm, children: const [
                          _Chip('FREE INSTALLATION', Color(0x33FFFFFF)),
                          _Chip('HD PICTURE', Color(0x33FFFFFF)),
                          _Chip('OTT APPS', Color(0x33FFFFFF)),
                        ]),
                      ]),
                ),
                const SizedBox(height: S.xl),
                const _Heading('CHOOSE AN OPTION'),
                const SizedBox(height: S.md),
                _Option(
                  icon: Icons.auto_awesome_outlined,
                  color: _violet,
                  title: 'Upgrade to Android',
                  note: 'DishTV SMRT HUB: live TV and OTT apps on any TV.',
                  tag: 'MOST SMART',
                  onTap: () => Navigator.of(context)
                      .push(_route(const UpgradeAndroidScreen())),
                ),
                const SizedBox(height: S.md),
                _Option(
                  icon: Icons.satellite_alt_outlined,
                  color: _orange,
                  title: 'Get a New Connection',
                  note: 'HD box with a pack for a new home.',
                  tag: 'FROM ₹931',
                  onTap: () => Navigator.of(context)
                      .push(_route(const GetNewConnectionScreen())),
                ),
                const SizedBox(height: S.md),
                _Option(
                  icon: Icons.connected_tv_outlined,
                  color: _teal,
                  title: 'Multi TV Connection',
                  note: 'Watch DishTV on another TV in your home.',
                  tag: 'ADD A TV',
                  onTap: () =>
                      Navigator.of(context).push(_route(const MultiTvScreen())),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.icon,
      required this.color,
      required this.title,
      required this.note,
      required this.tag,
      required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String note;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $note',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              color: C.surface,
              child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 60, child: Icon(icon, color: C.ink, size: 26)),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(S.md, S.md, S.sm, S.md),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 3),
                                    Text(note,
                                        style:
                                            T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                                    const SizedBox(height: 6),
                                    _Chip(tag, Colors.transparent, color: C.faint),
                                  ]),
                            ),
                            Icon(Icons.chevron_right_sharp,
                                color: C.faint),
                          ]),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Upgrade to Android

const _smrtOrder = _Order(
  name: 'DishTV SMRT HUB',
  detail: 'SMRT Plan · one-time',
  price: _boxPrice,
  icon: Icons.router_outlined,
  accent: _violet,
  successTitle: 'Box upgrade confirmed',
  successLine: 'We will deliver and install your DishTV SMRT HUB in 3-5 days.',
);

class UpgradeAndroidScreen extends StatelessWidget {
  const UpgradeAndroidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Upgrade to Android'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                // Hero: the box, its name and the price, centred on one solid colour.
                Container(
                  decoration: BoxDecoration(gradient: _card(_violet)),
                  padding: const EdgeInsets.fromLTRB(S.lg, S.xl, S.lg, S.xl),
                  child: Column(children: [
                    Text('SMRT PLAN',
                        style: T.overline.copyWith(
                            color: _softWhite,
                            fontSize: 12,
                            letterSpacing: 1.4)),
                    const SizedBox(height: S.xl),
                    const _BoxArt(scale: 1.35),
                    const SizedBox(height: S.xl),
                    Text('DishTV SMRT HUB',
                        style: T.title
                            .copyWith(color: Colors.white, fontSize: 21)),
                    const SizedBox(height: S.sm),
                    Text('${rupees(_boxPrice)}*',
                        style: T.price
                            .copyWith(fontSize: 40, color: Colors.white)),
                    const SizedBox(height: S.xs),
                    Text('One-time · delivered & installed',
                        style: T.caption
                            .copyWith(color: _softWhite, fontSize: 13.5)),
                  ]),
                ),
                const SizedBox(height: S.xxl),
                const _Heading('WHAT YOU GET', color: _violet),
                const _InfoRow(
                    icon: Icons.auto_awesome_outlined,
                    color: _violet,
                    title: 'Smart home screen',
                    note:
                        'Customise it your way. Live TV and OTT apps in one place.'),
                const _InfoRow(
                    icon: Icons.wifi_sharp,
                    color: _teal,
                    title: 'Make any TV smart',
                    note:
                        'Plug it in and your TV gets apps, streaming and more.'),
                const _InfoRow(
                    icon: Icons.mic_none_sharp,
                    color: _orange,
                    title: 'Voice search',
                    note:
                        'Find shows and channels by speaking, with Google Assistant.'),
                const _InfoRow(
                    icon: Icons.verified_user_outlined,
                    color: _green,
                    title: 'Lifetime service warranty',
                    note: 'Free service for as long as you own the box.',
                    last: true),
                const SizedBox(height: S.lg),
                Container(
                  padding: const EdgeInsets.all(S.lg),
                  color: C.surface,
                  child: Row(children: [
                    Icon(Icons.local_shipping_outlined,
                        color: C.ink, size: 22),
                    const SizedBox(width: S.md),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivered and installed',
                                style: T.item.copyWith(fontSize: 15.5)),
                            const SizedBox(height: 2),
                            Text(
                                'Within 3-5 days. Works best with the All-in-one pack.',
                                style: T.caption.copyWith(fontSize: 13.5)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: S.xl),
                Center(
                  child: InkWell(
                    onTap: () => _toast(context,
                        'Callback requested. We will call you shortly.'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: S.sm, horizontal: S.md),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        BrandShade(child: Icon(Icons.phone_callback_outlined,
                            color: C.brand, size: 20)),
                        const SizedBox(width: S.sm),
                        Text('Need more details? ',
                            style: T.body.copyWith(color: C.muted)),
                        BrandShade(child: Text('Get a callback',
                            style: T.body.copyWith(
                                color: C.brand, fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: S.xs),
                Center(
                    child: Text('*GST extra. T&C apply.',
                        style: T.caption.copyWith(color: C.faint))),
              ],
            ),
          ),
          BottomBar(
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('DishTV SMRT HUB', style: T.caption),
                      Text('${rupees(_boxPrice)}*',
                          style:
                              T.price.copyWith(fontSize: 21, color: C.ink)),
                    ]),
              ),
              SizedBox(
                  width: 170,
                  child: PrimaryButton(
                      label: 'Upgrade',
                      onTap: () => Navigator.of(context).push(
                          _route(const BoxReviewScreen(order: _smrtOrder))))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Get a New Connection

class _Plan {
  const _Plan(
      {required this.tag,
      required this.badge,
      required this.color,
      required this.price,
      required this.note,
      required this.features,
      this.pincode = false,
      this.packLabel = ''});

  final String tag;
  final String badge;
  final Color color;
  final double price;
  final String note;
  final List<(IconData, String)> features;
  final bool pincode;
  final String packLabel;
}

const _plans = [
  _Plan(
    tag: 'HD Plan With Pack',
    badge: 'POPULAR',
    color: _orange,
    price: 1355,
    note: 'With 3 months pack',
    packLabel: 'With 3 months pack',
    features: [
      (Icons.account_balance_wallet_outlined, 'Enjoy non-stop TV for 1 year**'),
      (Icons.connected_tv_outlined, '3 months entertainment pack included'),
      (Icons.layers_outlined, 'Customise your pack & switch channels in HD/SD'),
    ],
  ),
  _Plan(
    tag: 'HD Cashback Plan',
    badge: 'SAVE ₹3,600',
    color: _violet,
    price: 2203,
    note: 'Get ₹3,600 total cashback',
    packLabel: 'Cashback',
    features: [
      (Icons.account_balance_wallet_outlined, '₹1,000 instant cashback'),
      (Icons.sell_outlined, '10% cashback on every recharge, up to ₹2,600'),
      (Icons.star_outline_sharp, 'Lifetime validity of the cashback'),
    ],
  ),
  _Plan(
    tag: 'HD Plan for South',
    badge: 'SOUTH INDIA',
    color: _teal,
    price: 1101,
    note: 'With 3 months pack',
    packLabel: 'South, 3 months pack',
    pincode: true,
    features: [
      (Icons.connected_tv_outlined, 'Popular regional channels'),
      (Icons.sports_soccer_outlined, 'Sports Always-ON channels**'),
      (Icons.router_outlined, 'HD set-top box with accessories'),
    ],
  ),
  _Plan(
    tag: 'HD Plan With Pack',
    badge: 'LOWEST PRICE',
    color: _blue,
    price: 931,
    note: 'With 1 month pack',
    packLabel: 'With 1 month pack',
    features: [
      (
        Icons.account_balance_wallet_outlined,
        'Price includes 1 month of entertainment pack'
      ),
      (Icons.star_outline_sharp, 'Value for money'),
      (Icons.router_outlined, 'HD set-top box with accessories'),
    ],
  ),
];

class GetNewConnectionScreen extends StatefulWidget {
  const GetNewConnectionScreen({super.key});

  @override
  State<GetNewConnectionScreen> createState() => _GetNewConnectionScreenState();
}

class _GetNewConnectionScreenState extends State<GetNewConnectionScreen> {
  int _selected = 0;
  /// A new home needs a dish antenna, so it starts on Yes.
  final _antenna = List<bool>.filled(_plans.length, true);
  final _pincode = TextEditingController();

  @override
  void dispose() {
    _pincode.dispose();
    super.dispose();
  }

  void _applyPincode() {
    FocusScope.of(context).unfocus();
    final v = _pincode.text.trim();
    _toast(
        context,
        RegExp(r'^\d{6}$').hasMatch(v)
            ? 'Pincode $v is serviceable'
            : 'Enter a valid 6-digit pincode');
  }

  void _info(_Plan p) => showSheet<void>(
        context,
        title: p.tag,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
              S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Text(
              '${p.note}. Price is one-time and excludes GST. ** Terms and conditions apply. Installation is done by a DishTV technician.',
              style: T.body.copyWith(fontSize: 14.5)),
        ),
      );

  void _select() {
    final p = _plans[_selected];
    final antenna = _antenna[_selected];
    Navigator.of(context).push(_route(BoxReviewScreen(
      order: _Order(
        name: 'Dish HD',
        detail:
            '${p.tag} · ${p.packLabel} · one-time\nAntenna: ${antenna ? 'Yes' : 'No'}',
        price: p.price,
        icon: Icons.satellite_alt_outlined,
        accent: p.color,
        successTitle: 'New connection booked',
        successLine: 'We will deliver and install your Dish HD in 3-5 days.',
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final cur = _plans[_selected];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(
              title: 'Get a New Connection',
              subtitle: 'Choose one plan. Prices are one-time.'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.md, S.page, S.xl),
              children: [
                for (final (i, p) in _plans.indexed) ...[
                  _planCard(i, p),
                  const SizedBox(height: S.md),
                ],
                const SizedBox(height: S.md),
                Center(
                  child: InkWell(
                    onTap: () => _toast(context,
                        'Callback requested. We will call you shortly.'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: S.sm, horizontal: S.md),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        BrandShade(child: Icon(Icons.phone_callback_outlined,
                            color: C.brand, size: 20)),
                        const SizedBox(width: S.sm),
                        Text('Need more details? ',
                            style: T.body.copyWith(color: C.muted)),
                        BrandShade(child: Text('Get a callback',
                            style: T.body.copyWith(
                                color: C.brand, fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: S.xs),
                Center(
                    child: Text('*GST extra. T&C apply.',
                        style: T.caption.copyWith(color: C.faint))),
              ],
            ),
          ),
          BottomBar(
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cur.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.caption),
                      Text('${rupees(cur.price)}*',
                          style: T.price.copyWith(fontSize: 21)),
                    ]),
              ),
              SizedBox(
                  width: 170,
                  child: PrimaryButton(label: 'Select', onTap: _select)),
            ]),
          ),
        ]),
      ),
    );
  }

  /// One plan. Collapsed it is a single tidy row; the chosen plan opens up to
  /// show its features, antenna choice and pincode.
  Widget _planCard(int i, _Plan p) {
    final on = i == _selected;
    return Semantics(
      button: true,
      selected: on,
      label: '${p.tag}, ${rupees(p.price)}. ${p.note}',
      child: Container(
        color: C.surface,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => _selected = i),
            child: IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(duration: const Duration(milliseconds: 200), width: 3, decoration: BoxDecoration(gradient: on ? G.brand : null)),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, S.lg),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BrandShade(on: on, child: Text(p.badge,
                                      style: T.overline.copyWith(
                                          color: on ? C.brand : C.muted,
                                          fontSize: 10.5,
                                          letterSpacing: 0.8))),
                                  const SizedBox(height: 4),
                                  Text('Dish HD · ${p.tag}',
                                      style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(p.note,
                                      style:
                                          T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                                ]),
                          ),
                          const SizedBox(width: S.md),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${rupees(p.price)}*',
                                    style: T.price.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: C.ink)),
                                const SizedBox(height: S.sm),
                                BrandShade(on: on, child: Icon(
                                    on
                                        ? Icons.check_circle_sharp
                                        : Icons.circle_outlined,
                                    color: on ? C.brand : C.faint,
                                    size: 22)),
                              ]),
                        ]),
                      ),
                    ),
                  ]),
            ),
          ),
          if (on) ...[
            Divider(height: 1, color: C.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(S.lg + 6, S.lg, S.lg, S.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in p.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: S.md),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(f.$1, size: 21, color: C.ink),
                              const SizedBox(width: S.md),
                              Expanded(
                                  child: Text(f.$2,
                                      style: T.body.copyWith(
                                          fontSize: 13.5,
                                          color: C.inkSoft,
                                          fontWeight: FontWeight.w500))),
                            ]),
                      ),
                    if (p.pincode) ...[
                      const SizedBox(height: S.xs),
                      Row(children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: S.md),
                            color: C.bg,
                            child: TextField(
                              controller: _pincode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style:
                                  T.body.copyWith(color: C.ink, fontSize: 15),
                              cursorColor: C.brand,
                              decoration: InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  hintText: 'Enter pincode',
                                  hintStyle: T.body.copyWith(color: C.faint),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: S.md),
                        InkWell(
                          onTap: _applyPincode,
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: S.xl),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(gradient: G.brand),
                            child: Text('Apply',
                                style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: S.lg),
                    ],
                    Row(children: [
                      Icon(Icons.settings_input_antenna_outlined,
                          color: C.ink, size: 21),
                      const SizedBox(width: S.md),
                      Expanded(
                          child: Text('Antenna needed?',
                              style: T.body.copyWith(
                                  fontSize: 14,
                                  color: C.ink,
                                  fontWeight: FontWeight.w500))),
                      _YesNo(
                          value: _antenna[i],
                          color: p.color,
                          onChanged: (v) => setState(() => _antenna[i] = v)),
                    ]),
                    const SizedBox(height: S.lg),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_sharp,
                              size: 18, color: C.success),
                          const SizedBox(width: S.sm),
                          Expanded(
                              child: Text(
                                  'Every plan includes Prime Lite, 5X picture quality, 5.1 surround sound and a 5-year warranty on the box and dish.',
                                  style: T.caption
                                      .copyWith(fontSize: 13, height: 1.45))),
                        ]),
                    const SizedBox(height: S.md),
                    InkWell(
                      onTap: () => _info(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: S.xs),
                        child: BrandShade(child: Text('More about this plan',
                            style: T.label.copyWith(
                                color: C.brand,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5))),
                      ),
                    ),
                  ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// A two-segment Yes / No switch; the chosen side is solid.
class _YesNo extends StatelessWidget {
  const _YesNo(
      {required this.value, required this.color, required this.onChanged});

  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool v) {
      final on = value == v;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkWell(
          onTap: () => onChanged(v),
          child: Container(
            width: 64,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: on ? _card(color) : null),
            child: Text(label,
                style: T.label.copyWith(
                    fontSize: 14,
                    color: on ? Colors.white : C.inkSoft,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Container(
      color: C.bg,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [seg('Yes', true), seg('No', false)]),
    );
  }
}

// ---------------------------------------------------------------------------
// Review & Confirm

class BoxReviewScreen extends StatefulWidget {
  const BoxReviewScreen({super.key, required this.order});

  final _Order order;

  @override
  State<BoxReviewScreen> createState() => _BoxReviewScreenState();
}

class _BoxReviewScreenState extends State<BoxReviewScreen> {
  bool _failed = false;

  _Order get _o => widget.order;

  Future<void> _pay() async {
    final result = await showSheet<bool>(
      context,
      title: 'Payment',
      subtitle: 'Pick what should happen to this payment.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SimButton(
                  icon: Icons.check_circle_outline_sharp,
                  label: 'Simulate success',
                  fill: _green,
                  onTap: () => Navigator.of(ctx).pop(true)),
              const SizedBox(height: S.md),
              _SimButton(
                  icon: Icons.cancel_outlined,
                  label: 'Simulate failure',
                  fill: _red,
                  onTap: () => Navigator.of(ctx).pop(false)),
            ]),
      ),
    );
    if (!mounted || result == null) return;
    if (result) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushAndRemoveUntil(
          _route(BoxSuccessScreen(order: _o)), (r) => r.isFirst);
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _failed = true);
      if (await _showFailure() == true && mounted) return _pay();
    }
  }

  /// True to try the payment again.
  Future<bool?> _showFailure() => showSheet<bool>(
        context,
        title: 'Payment failed',
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
              S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(S.lg),
                  decoration: BoxDecoration(
                      color: C.dangerSoft,
                      border: Border.all(color: C.danger.withAlpha(120))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_sharp,
                            color: C.danger, size: 26),
                        const SizedBox(width: S.md),
                        Expanded(
                            child: Text(
                                'We could not complete your payment of ${rupees(_o.total)}. No money was taken. Please try again.',
                                style: T.body
                                    .copyWith(color: C.ink, fontSize: 14.5))),
                      ]),
                ),
                const SizedBox(height: S.lg),
                PrimaryButton(
                    label: 'Try again',
                    onTap: () => Navigator.of(ctx).pop(true)),
                const SizedBox(height: S.sm),
                SecondaryButton(
                    label: 'Not now',
                    onTap: () => Navigator.of(ctx).pop(false)),
              ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(
              title: 'Review & Confirm',
              subtitle: 'Check your order before paying'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.lg),
              children: [
                if (_failed)
                  Container(
                    margin: const EdgeInsets.only(bottom: S.md),
                    padding: const EdgeInsets.all(S.md),
                    decoration: BoxDecoration(
                        color: C.dangerSoft,
                        border: Border.all(color: C.danger.withAlpha(120))),
                    child: Row(children: [
                      Icon(Icons.error_outline_sharp,
                          color: C.danger, size: 20),
                      const SizedBox(width: S.sm),
                      Expanded(
                          child: Text('Last payment failed. Try again below.',
                              style: T.label.copyWith(color: C.danger))),
                    ]),
                  ),
                _Band(
                  color: _o.accent,
                  watermark: _o.icon,
                  child: Row(children: [
                    SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(_o.icon, color: Colors.white, size: 34)),
                    const SizedBox(width: S.md),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_o.name,
                                style: T.title.copyWith(
                                    color: Colors.white, fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(_o.detail,
                                style: T.caption
                                    .copyWith(color: _softWhite, fontSize: 13)),
                          ]),
                    ),
                    const SizedBox(width: S.sm),
                    Text(rupees(_o.price),
                        style: T.price
                            .copyWith(fontSize: 20, color: Colors.white)),
                  ]),
                ),
                const SizedBox(height: S.lg),
                const _Heading('WHAT HAPPENS NEXT', color: _teal),
                const SizedBox(height: S.md),
                const _Steps([
                  (Icons.payments_outlined, 'Pay', 'Now'),
                  (Icons.local_shipping_outlined, 'Delivery', 'In 3-5 days'),
                  (Icons.handyman_outlined, 'Install', 'Free'),
                ], _teal),
                const SizedBox(height: S.lg),
                Container(
                  padding: const EdgeInsets.all(S.md),
                  color: C.surface,
                  child: Row(children: [
                    Icon(Icons.lock_outline_sharp,
                        color: C.inkSoft, size: 20),
                    const SizedBox(width: S.md),
                    Expanded(
                        child: Text(
                            'Secure payment. Your details are protected.',
                            style:
                                T.body.copyWith(fontSize: 13, color: C.inkSoft))),
                  ]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(S.page, S.lg, S.page,
                S.lg + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
                color: C.surface,
                border: Border(top: BorderSide(color: C.line))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AMOUNT', style: T.overline),
                  const SizedBox(height: S.sm),
                  _row(_o.name, rupees(_o.price)),
                  _row('GST (18%)', rupees(_o.gst)),
                  Divider(height: S.lg, color: C.line),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Total', style: T.item.copyWith(fontSize: 17)),
                        const SizedBox(width: 6),
                        Text('one-time', style: T.caption),
                        const Spacer(),
                        BrandShade(child: Text(rupees(_o.total),
                            style:
                                T.price.copyWith(fontSize: 24, color: C.brand))),
                      ]),
                  const SizedBox(height: S.lg),
                  PrimaryButton(
                      label: 'Pay ${rupees(_o.total.roundToDouble())}',
                      icon: Icons.lock_outline_sharp,
                      onTap: _pay),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a, style: T.body)),
          Text(b, style: T.label.copyWith(fontSize: 14)),
        ]),
      );
}

class _SimButton extends StatelessWidget {
  const _SimButton(
      {required this.icon,
      required this.label,
      required this.fill,
      required this.onTap});

  final IconData icon;
  final String label;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 56,
              color: fill,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: S.sm),
                Text(label,
                    style: T.item.copyWith(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Success

class BoxSuccessScreen extends StatefulWidget {
  const BoxSuccessScreen({super.key, required this.order});

  final _Order order;

  @override
  State<BoxSuccessScreen> createState() => _BoxSuccessScreenState();
}

class _BoxSuccessScreenState extends State<BoxSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final String _orderId =
      'DT${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
  late final DateTime _delivery = DateTime.now().add(const Duration(days: 5));

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(
        parent: _a,
        curve: Interval(from, (from + 0.4).clamp(0, 1),
            curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: c,
        child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(c),
            child: child));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: Stack(children: [
          // Behind the content and clear of the status bar.
          const Positioned.fill(child: SafeArea(child: Confetti())),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 40, S.page, S.xl),
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                            parent: _a,
                            curve: const Interval(0, 0.45,
                                curve: Curves.elasticOut)),
                        child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                                color: C.success, shape: BoxShape.circle),
                            child: const Icon(Icons.check_sharp,
                                color: Colors.white, size: 46)),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.25,
                      Column(children: [
                        Text(o.successTitle,
                            textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text(o.successLine,
                            textAlign: TextAlign.center, style: T.body),
                        const SizedBox(height: S.md),
                        Text('Order ID · $_orderId',
                            style: T.label.copyWith(color: C.muted)),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.4,
                      IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: _tile(
                                      'DELIVERY BY',
                                      '${_delivery.day} ${_months[_delivery.month - 1]}',
                                      _teal,
                                      Icons.local_shipping_outlined)),
                              const SizedBox(width: S.sm),
                              Expanded(
                                  child: _tile(
                                      'PAID',
                                      rupees(o.total.roundToDouble()),
                                      _orange,
                                      Icons.payments_outlined)),
                            ]),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    _fade(
                      0.5,
                      Container(
                        padding: const EdgeInsets.all(S.md),
                        color: C.surface,
                        child: Row(children: [
                          Icon(o.icon, size: 24, color: C.ink),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.name,
                                      style: T.item.copyWith(fontSize: 16)),
                                  Text(o.detail.replaceAll(' · one-time', ''),
                                      style: T.caption),
                                ]),
                          ),
                          Text(rupees(o.price),
                              style: T.price.copyWith(fontSize: 17)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    _fade(
                      0.6,
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Heading('WHAT HAPPENS NEXT', color: _teal),
                            const SizedBox(height: S.md),
                            const _Steps([
                              (
                                Icons.check_circle_outline_sharp,
                                'Confirmed',
                                'Done'
                              ),
                              (
                                Icons.local_shipping_outlined,
                                'Dispatch',
                                'In 1-2 days'
                              ),
                              (
                                Icons.handyman_outlined,
                                'Install',
                                'By technician'
                              ),
                            ], _teal),
                          ]),
                    ),
                  ],
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg),
                  child: PrimaryButton(label: 'Done', onTap: _done)),
            ]),
          ),
        ]),
      ),
    );
  }

  /// A quiet figure: grey label, bold value, small white icon.
  Widget _tile(String label, String value, Color fill, IconData icon) => Container(
        color: C.surface,
        padding: const EdgeInsets.all(S.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: C.inkSoft),
            const SizedBox(width: 6),
            Text(label[0] + label.substring(1).toLowerCase(), style: T.caption.copyWith(fontSize: 12, color: C.muted)),
          ]),
          const SizedBox(height: 6),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: T.price.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: C.ink))),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Multi TV Connection

class MultiTvScreen extends StatefulWidget {
  const MultiTvScreen({super.key});

  @override
  State<MultiTvScreen> createState() => _MultiTvScreenState();
}

/// What a Multi TV connection costs: the extra box once, and the network
/// fee each month (channels on top, or share the main TV's pack).
const _multiTvBox = 1690.0;
const _multiTvMonthly = 153.0;

class _MultiTvScreenState extends State<MultiTvScreen> {
  late final TextEditingController _mobile = TextEditingController(
      text: context.read<AppStore>().subscriber?.mobile ?? '')
    ..addListener(() => setState(() {}));

  /// The account's own number needs no OTP: you're already signed in.
  bool get _registered => _mobile.text == context.read<AppStore>().subscriber?.mobile;

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_mobile.text);

  String get _pretty =>
      '${_mobile.text.substring(0, 5)} ${_mobile.text.substring(5)}';

  void _know() => showSheet<void>(
        context,
        title: 'About Multi TV',
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
              S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in const [
                  (
                    Icons.connected_tv_outlined,
                    'Watch DishTV on another TV in your home.',
                    _orange
                  ),
                  (
                    Icons.layers_outlined,
                    'Share your pack across TVs with one extra box.',
                    _violet
                  ),
                  (Icons.hd_outlined, 'Pick HD or SD for each TV.', _teal),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(t.$1, color: C.ink, size: 22),
                      const SizedBox(width: S.md),
                      Expanded(
                          child: Text(t.$2,
                              style: T.body
                                  .copyWith(color: C.ink, fontSize: 14.5))),
                    ]),
                  ),
              ]),
        ),
      );

  Future<void> _book() async {
    FocusScope.of(context).unfocus();
    if (!_valid) return;
    // Only a different number has to be verified.
    if (!_registered) {
      final ok = await showSheet<bool>(context,
          title: 'Verify mobile number',
          builder: (_) => _OtpSheet(pretty: '+91 $_pretty'));
      if (ok != true || !mounted) return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushAndRemoveUntil(
        _route(_MultiTvSuccessScreen(pretty: '+91 $_pretty')),
        (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Multi TV Connection'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                Container(
                  decoration: BoxDecoration(gradient: _card(_teal)),
                  padding: const EdgeInsets.all(S.xl),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                  child: Text('Add another TV to your home',
                                      style: T.display.copyWith(
                                          color: Colors.white,
                                          fontSize: 24,
                                          height: 1.2))),
                              const SizedBox(width: S.md),
                              const _BoxArt(scale: 0.7),
                            ]),
                        const SizedBox(height: S.md),
                        Text(
                            "Get DishTV's Multi TV Connection and don't compromise on your entertainment.",
                            style: T.body
                                .copyWith(color: _softWhite, fontSize: 14.5)),
                        const SizedBox(height: S.lg),
                        InkWell(
                          onTap: _know,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Know more',
                                style: T.label.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5)),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_sharp,
                                color: Colors.white, size: 18),
                          ]),
                        ),
                      ]),
                ),
                const SizedBox(height: S.xxl),
                const _Heading('WHY MULTI TV', color: _teal),
                const _InfoRow(
                    icon: Icons.connected_tv_outlined,
                    color: _orange,
                    title: 'One more TV',
                    note: 'Watch DishTV on another TV in your home.'),
                const _InfoRow(
                    icon: Icons.hd_outlined,
                    color: _violet,
                    title: 'HD or SD',
                    note: 'Pick the picture quality for each TV.'),
                const _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    color: _blue,
                    title: 'One bill',
                    note: 'Every TV on one account and one recharge.',
                    last: true),
                const SizedBox(height: S.xl),
                const _Heading('WHAT IT COSTS', color: _violet),
                const SizedBox(height: S.md),
                Container(
                  color: C.surface,
                  padding: const EdgeInsets.all(S.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final (what, note, price) in [
                      ('Extra set-top box', 'One time, installation included', rupees(_multiTvBox)),
                      ('Every month', 'Network fee with GST. Add channels, or share your pack', 'from ${rupees(_multiTvMonthly)}'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(what, style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(note, style: T.caption.copyWith(fontSize: 12.5)),
                            ]),
                          ),
                          const SizedBox(width: S.md),
                          Text(price, style: T.price.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: S.xl),
                const _Heading('BOOK YOUR CONNECTION'),
                const SizedBox(height: S.lg),
                Text('Mobile number', style: T.label.copyWith(fontSize: 14)),
                const SizedBox(height: S.sm),
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: S.lg),
                  color: C.surface,
                  child: Row(children: [
                    Text('+91',
                        style: T.item.copyWith(fontSize: 17, color: C.inkSoft)),
                    Container(
                        width: 1,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: S.md),
                        color: C.lineStrong),
                    Expanded(
                      child: TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: T.item.copyWith(fontSize: 18),
                        cursorColor: C.brand,
                        decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            isCollapsed: true),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: S.sm),
                Row(children: [
                  Icon(Icons.sms_outlined, size: 16, color: C.muted),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text(
                        _registered ? 'Your registered number. We\'ll call you on it.' : 'We\'ll send an OTP to verify this number.',
                        style: T.caption.copyWith(fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: S.xxl),
                const _Heading('WHAT HAPPENS NEXT', color: _orange),
                const SizedBox(height: S.lg),
                const _Steps([
                  (Icons.sms_outlined, 'Verify', 'With OTP'),
                  (Icons.phone_in_talk_outlined, 'We call', 'Within a day'),
                  (Icons.connected_tv_outlined, 'Connected', 'Extra TV live'),
                ], _orange),
              ],
            ),
          ),
          BottomBar(child: PrimaryButton(label: 'Book Now', onTap: _valid ? _book : null)),
        ]),
      ),
    );
  }
}

/// Six boxes driven by one hidden text field. Any six digits are accepted.
class _OtpSheet extends StatefulWidget {
  const _OtpSheet({required this.pretty});

  final String pretty;

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = 26;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _left = 26;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      if (mounted) setState(() => _left = (_left - 1).clamp(0, 99));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _code.text;
    final full = text.length == 6;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          S.page,
          S.sm,
          S.page,
          S.xl +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
                TextSpan(style: T.body.copyWith(fontSize: 14.5), children: [
              const TextSpan(text: "We've sent a 6-digit OTP to "),
              TextSpan(
                  text: widget.pretty,
                  style: T.body.copyWith(
                      fontSize: 14.5,
                      color: C.ink,
                      fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(height: S.lg),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focus.requestFocus();
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              child: Stack(children: [
                Row(children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: S.sm),
                    Expanded(
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.surface,
                          border: i == text.length ? Border.all(color: C.brand, width: 1.5) : null,
                        ),
                        child: Text(i < text.length ? text[i] : '',
                            style: T.title.copyWith(fontSize: 22)),
                      ),
                    ),
                  ],
                ]),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _code,
                      focusNode: _focus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          counterText: '', border: InputBorder.none),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: S.sm),
            Row(children: [
              Text(kDebugMode ? 'Test build: any 6 digits work' : 'Enter the code from the SMS', style: T.caption),
              const Spacer(),
              _left > 0
                  ? Text('Resend OTP in 0:${_left.toString().padLeft(2, '0')}',
                      style: T.label.copyWith(color: C.inkSoft))
                  : InkWell(
                      onTap: () => setState(() {
                        _code.clear();
                        _startTimer();
                      }),
                      child: BrandShade(child: Text('Resend OTP',
                          style: T.label.copyWith(
                              color: C.brand, fontWeight: FontWeight.w800))),
                    ),
            ]),
            const SizedBox(height: S.lg),
            PrimaryButton(
                label: 'Verify & Book',
                onTap: full ? () => Navigator.of(context).pop(true) : null),
          ]),
    );
  }
}

class _MultiTvSuccessScreen extends StatefulWidget {
  const _MultiTvSuccessScreen({required this.pretty});

  final String pretty;

  @override
  State<_MultiTvSuccessScreen> createState() => _MultiTvSuccessScreenState();
}

class _MultiTvSuccessScreenState extends State<_MultiTvSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final String _id =
      'SR${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
        parent: _a,
        curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: Stack(children: [
          // Behind the content and clear of the status bar.
          const Positioned.fill(child: SafeArea(child: Confetti())),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.page, 40, S.page, S.xl),
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                            parent: _a,
                            curve: const Interval(0, 0.45,
                                curve: Curves.elasticOut)),
                        child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                                color: C.success, shape: BoxShape.circle),
                            child: const Icon(Icons.check_sharp,
                                color: Colors.white, size: 46)),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    FadeTransition(
                      opacity: fade,
                      child: Column(children: [
                        Text('Booking request received',
                            textAlign: TextAlign.center, style: T.display),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(style: T.body, children: [
                            const TextSpan(text: 'Our team will call you on '),
                            TextSpan(
                                text: widget.pretty,
                                style: T.body.copyWith(
                                    color: C.ink, fontWeight: FontWeight.w800)),
                            const TextSpan(
                                text: ' to book your Multi TV connection.'),
                          ]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: S.md),
                        Text('Request ID · $_id',
                            style: T.label.copyWith(color: C.muted)),
                      ]),
                    ),
                    const SizedBox(height: S.xl),
                    FadeTransition(
                      opacity: fade,
                      child: Container(
                        color: C.surface,
                        padding: const EdgeInsets.all(S.lg),
                        child: Row(children: [
                          Icon(Icons.phone_in_talk_outlined,
                              color: C.ink, size: 22),
                          const SizedBox(width: S.md),
                          Expanded(
                              child: Text(
                                  'Keep your phone handy. We usually call within a day.',
                                  style: T.body.copyWith(
                                      color: C.inkSoft, fontSize: 13.5))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: S.xl),
                    FadeTransition(
                      opacity: fade,
                      child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Heading('WHAT HAPPENS NEXT', color: _orange),
                            SizedBox(height: S.md),
                            _Steps([
                              (
                                Icons.check_circle_outline_sharp,
                                'Requested',
                                'Done'
                              ),
                              (
                                Icons.phone_in_talk_outlined,
                                'We call',
                                'Within a day'
                              ),
                              (
                                Icons.connected_tv_outlined,
                                'Connected',
                                'Extra TV live'
                              ),
                            ], _orange),
                          ]),
                    ),
                  ],
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg),
                  child: PrimaryButton(label: 'Done', onTap: _done)),
            ]),
          ),
        ]),
      ),
    );
  }
}
