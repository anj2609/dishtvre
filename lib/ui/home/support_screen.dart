// Contact Customer Support: the selected TV and its pack, ways to get in touch
// and more help. Plain icons, solid colour, sharp corners.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../change_pack/switch_tv_sheet.dart';
import '../setup_box/setup_box_screens.dart';
import '../widgets/widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  EdgeInsets _pad(BuildContext ctx) => EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom);

  void _callSheet(BuildContext context, String title, List<String> numbers) => showSheet<void>(
        context,
        title: title,
        subtitle: 'For any queries or issues, please feel free to call us on',
        builder: (ctx) => Padding(
          padding: _pad(ctx),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final n in numbers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: S.sm),
                child: Row(children: [
                  Icon(Icons.phone_outlined, color: C.ink, size: 22),
                  const SizedBox(width: S.md),
                  Expanded(child: Text(n, style: T.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600))),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _toast(context, 'Calling $n...');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: 10),
                      decoration: const BoxDecoration(gradient: G.brand),
                      child: Text('Call', style: T.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: S.md),
            Row(children: [
              Icon(Icons.info_outline, size: 20, color: C.muted),
              const SizedBox(width: S.sm),
              Text('Local call charges apply.', style: T.caption.copyWith(fontSize: 14)),
            ]),
          ]),
        ),
      );

  void _infoSheet(BuildContext context, String title, String body, String button, VoidCallback onTap) => showSheet<void>(
        context,
        title: title,
        subtitle: body,
        builder: (ctx) => Padding(
          padding: _pad(ctx),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrimaryButton(
              label: button,
              onTap: () {
                Navigator.of(ctx).pop();
                onTap();
              },
            ),
          ]),
        ),
      );

  void _dealerSheet(BuildContext context) => showSheet<void>(
        context,
        title: 'Locate a Dealer',
        subtitle: 'Find your nearest DishTV dealer.',
        builder: (_) => _DealerForm(onFound: (pin) => _toast(context, 'Showing dealers near $pin')),
      );

  void _nodalSheet(BuildContext context) => showSheet<void>(
        context,
        title: 'Nodal Officer Details',
        subtitle: "Choose your state to see the nodal officer's contact details.",
        builder: (_) => const _NodalForm(),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStore>();
    final c = app.connection;
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    final touch = [
      (Icons.phone_outlined, C.brand, '24 × 7 Call Support', 'Talk to our support team anytime, day or night.', () => _callSheet(context, '24 × 7 Call Support', const ['+91 95017 95017', '1800 120 3474'])),
      (Icons.chat_outlined, C.brand, 'WhatsApp Support', 'Chat with us on WhatsApp for quick assistance.', () => _toast(context, 'Opening WhatsApp...')),
      (Icons.schedule_outlined, C.violet, 'Request a Callback', 'Give us a missed call. Our team will call you back.', () => _toast(context, 'Callback requested. We will call you shortly.')),
    ];
    final more = [
      (Icons.satellite_alt_outlined, C.brand, 'Book a New Connection', 'Get DishTV at a new home or for someone else.', () => _infoSheet(context, 'Book a New Connection', 'Get a new DishTV connection installed at your home, or book one for family and friends.', 'Book a new connection', () => open(const GetNewConnectionScreen()))),
      (Icons.home_outlined, C.teal, 'Shifting DishTV', "Moving house? We'll help you shift your connection.", () => _callSheet(context, 'Shifting DishTV', const ['+91 95017 95017'])),
      (Icons.emoji_events_outlined, C.warning, 'Become Our Online Affiliate', 'Earn monthly incentives with a small investment.', () => _infoSheet(context, 'Become Our Online Affiliate', 'Start your journey with DishTV to earn enticing monthly incentives by making a minimum investment.', 'Apply now', () => _toast(context, 'Application started. We will contact you shortly.'))),
      (Icons.location_on_outlined, C.info, 'Locate a Dealer', 'Find your nearest DishTV dealer by pincode.', () => _dealerSheet(context)),
      (Icons.connected_tv_outlined, C.violet, 'Corporate Connection', 'Deals on corporate and bulk connections.', () => _toast(context, 'Corporate connections')),
      (Icons.person_outline_sharp, C.brand, 'Nodal Officer Details', 'Contact details of the nodal officer in your state.', () => _nodalSheet(context)),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Contact Customer Support'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(S.page, 0, S.page, S.sm + MediaQuery.paddingOf(context).bottom),
              children: [
                if (c != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: 'Change TV. ${c.label}, VC ${c.vcPretty}',
                      child: InkWell(
                        onTap: app.connections.length > 1
                            ? () async {
                                final vc = await showSwitchTvSheet(context);
                                if (vc != null) app.selectVc(vc);
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: S.sm),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(c.label, style: T.label.copyWith(fontSize: 13, color: C.ink, fontWeight: FontWeight.w600)),
                            Text('  ·  VC ${c.vcPretty}', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                            if (app.connections.length > 1) Icon(Icons.keyboard_arrow_down_sharp, color: C.muted, size: 20),
                          ]),
                        ),
                      ),
                    ),
                  ),
                if (c != null)
                  Container(
                    margin: const EdgeInsets.only(top: S.xs),
                    padding: const EdgeInsets.all(S.lg + 2),
                    decoration: const BoxDecoration(gradient: G.brand),
                    child: IntrinsicHeight(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Current pack', style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
                            const SizedBox(height: 4),
                            Text(c.planName, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: S.lg), color: const Color(0x40FFFFFF)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Next recharge', style: T.caption.copyWith(fontSize: 12, color: const Color(0xD9FFFFFF))),
                          const SizedBox(height: 4),
                          Text('${c.switchOffDate.day} ${_months[c.switchOffDate.month - 1]}', style: T.title.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        ]),
                      ]),
                    ),
                  ),
                const _Heading('Get in touch'),
                _Group([for (final t in touch) _Row(icon: t.$1, title: t.$3, note: t.$4, onTap: t.$5)]),
                const _Heading('More help'),
                _Group([for (final t in more) _Row(icon: t.$1, title: t.$3, note: t.$4, onTap: t.$5)]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: S.xxl, bottom: S.sm + 2),
        child: Semantics(header: true, child: Text(text, style: T.section.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
      );
}

/// Rows straight on the page, like the side menu: no panel behind them and
/// no lines between them; spacing does the work.
class _Group extends StatelessWidget {
  const _Group(this.rows);
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => Column(children: rows);
}

/// A help row: white line icon, title, short grey note, faint chevron.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.note, required this.onTap});

  final IconData icon;
  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $note',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                SizedBox(width: 30, child: Icon(icon, size: 22, color: C.ink)),
                const SizedBox(width: S.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: T.item.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(note, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                  ]),
                ),
                Icon(Icons.chevron_right_sharp, color: C.faint, size: 20),
              ]),
            ),
          ),
        ),
      );
}

const _states = ['Andhra Pradesh', 'Assam', 'Bihar', 'Delhi', 'Gujarat', 'Karnataka', 'Kerala', 'Maharashtra', 'Punjab', 'Rajasthan', 'Tamil Nadu', 'Telangana', 'Uttar Pradesh', 'West Bengal'];

/// A labelled text field used inside the support sheets: an underline, no
/// box.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.caption.copyWith(fontSize: 12, color: C.muted)),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.lineStrong, width: 1.2))),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ]);
}

class _DealerForm extends StatefulWidget {
  const _DealerForm({required this.onFound});
  final ValueChanged<String> onFound;

  @override
  State<_DealerForm> createState() => _DealerFormState();
}

class _DealerFormState extends State<_DealerForm> {
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Field(
            label: 'Pincode',
            child: TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: T.item.copyWith(fontSize: 16),
              cursorColor: C.brand,
              decoration: InputDecoration(counterText: '', border: InputBorder.none, isCollapsed: true, hintText: 'e.g. 201301', hintStyle: T.body.copyWith(color: C.faint, fontSize: 16)),
            ),
          ),
          const SizedBox(height: S.lg),
          PrimaryButton(
            label: 'Locate',
            onTap: _pin.text.length == 6
                ? () {
                    final pin = _pin.text;
                    Navigator.of(context).pop();
                    widget.onFound(pin);
                  }
                : null,
          ),
        ]),
      );
}

class _NodalForm extends StatefulWidget {
  const _NodalForm();

  @override
  State<_NodalForm> createState() => _NodalFormState();
}

class _NodalFormState extends State<_NodalForm> {
  String? _state;

  Future<void> _pick() async {
    final v = await showSheet<String>(
      context,
      title: 'Select state',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final st in _states)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(st),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: S.md),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                child: Row(children: [
                  Expanded(child: Text(st, style: T.item.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500))),
                  if (st == _state) BrandShade(child: Icon(Icons.check_sharp, color: C.brand)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (v != null && mounted) setState(() => _state = v);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: _pick,
            child: _Field(
              label: 'State',
              child: Row(children: [
                Expanded(child: Text(_state ?? 'Select state', style: T.item.copyWith(fontSize: 16, color: _state == null ? C.muted : C.ink))),
                Icon(Icons.keyboard_arrow_down_sharp, color: C.ink),
              ]),
            ),
          ),
          if (_state != null) ...[
            const SizedBox(height: S.lg),
            Padding(
              padding: const EdgeInsets.only(top: S.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nodal officer · $_state', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                const SizedBox(height: S.sm),
                Text('Customer Care Nodal Officer', style: T.item.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                BrandShade(child: Text('nodal.${_state!.toLowerCase().replaceAll(' ', '')}@dishtv.example', style: T.caption.copyWith(fontSize: 14, color: C.brand))),
                Text('1800 120 3474', style: T.caption.copyWith(fontSize: 14, color: C.ink)),
              ]),
            ),
          ],
        ]),
      );
}
