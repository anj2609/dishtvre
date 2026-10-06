// Recharge for Friends & Family: type the mobile number linked to someone
// else's DishTV connection, see the connection it finds, and continue to
// the usual Recharge screen for that connection. Numbers that aren't valid,
// are your own, or have no connection each say so and what to do instead.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'recharge_screen.dart' show RechargeScreen;

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _pretty(String m) => '${m.substring(0, 5)} ${m.substring(5)}';

/// Numbers looked up this session, newest first, for one-tap reuse.
final _recent = ValueNotifier<List<(String, String)>>([]);

/// Mock lookup: every valid number finds a connection, built from the
/// number so the same number always finds the same one, except numbers
/// ending in 0000, which have none.
Connection? _lookup(String mobile) {
  if (mobile.endsWith('0000')) return null;
  const names = ['Sunita Mehra', 'Rahul Verma', 'Priya Nair', 'Arjun Singh', 'Meera Iyer', 'Vikram Rao', 'Anita Desai', 'Karan Malhotra'];
  const packs = [('Flexi Hindi', 234.0), ('Super Family Hindi', 329.0), ('Hindi Family Saver', 249.0), ('Titanium Sports', 499.0), ('Marathi Mega', 279.0)];
  final n = int.parse(mobile.substring(4));
  final pack = packs[(n ~/ 7) % packs.length];
  final off = _day(DateTime.now()).add(Duration(days: n % 23 - 3));
  return Connection(
    vc: '0102${mobile.substring(3)}',
    label: names[n % names.length],
    type: ConnectionType.individual,
    status: off.isAfter(_day(DateTime.now())) ? ConnectionStatus.active : ConnectionStatus.deactivated,
    monthlyRecharge: pack.$2,
    balance: 0,
    switchOffDate: off,
    planName: pack.$1,
    isHd: n.isEven,
  );
}

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
  final _number = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  /// What went wrong with the last lookup, and an action to go with it.
  String? _error;
  bool _ownNumber = false;

  @override
  void initState() {
    super.initState();
    _number.addListener(() {
      if (_error != null) setState(() => _error = null);
      setState(() {});
    });
    // Ready to type straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _complete => _number.text.length == 10;

  Future<void> _find() async {
    final m = _number.text;
    final own = context.read<AppStore>().subscriber?.mobile;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(m)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (m == own) {
      setState(() {
        _error = 'That\'s your own number.';
        _ownNumber = true;
      });
      return;
    }
    _focus.unfocus();
    setState(() {
      _busy = true;
      _ownNumber = false;
    });
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final c = _lookup(m);
    setState(() => _busy = false);
    if (c == null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'No DishTV connection is linked to this number. Check it and try again.');
      return;
    }
    HapticFeedback.selectionClick();
    _recent.value = [(m, c.label), ..._recent.value.where((r) => r.$1 != m)].take(3).toList();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DetailsScreen(c: c, mobile: m)));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Recharge for Friends & Family'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text('Enter the mobile number of the connection you want to recharge',
                    style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: S.xl),
                Text('Mobile number', style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.inkSoft)),
                const SizedBox(height: S.sm),
                // +91 | number. An orange edge while typing, red on an error.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 56,
                  decoration: BoxDecoration(
                    color: C.surface,
                    border: Border.all(color: error != null ? C.danger : (_focus.hasFocus ? C.brand : C.surface), width: 1.2),
                  ),
                  padding: const EdgeInsets.only(left: S.lg),
                  child: Row(children: [
                    Text('+91', style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: C.inkSoft)),
                    Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: S.md), color: C.lineStrong),
                    Expanded(
                      child: Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _number,
                          focusNode: _focus,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.search,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          onSubmitted: (_) => _complete ? _find() : null,
                          style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                          cursorColor: C.brand,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '98765 43210',
                            hintStyle: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: C.faint),
                          ),
                        ),
                      ),
                    ),
                    if (_number.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _number.clear();
                          _focus.requestFocus();
                        },
                        icon: Icon(Icons.close_sharp, size: 20, color: C.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: S.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
                  child: error == null
                      ? Text('We\'ll find the connection linked to this number',
                          key: const ValueKey('hint'), style: T.caption.copyWith(fontSize: 12.5, color: C.muted))
                      : Row(key: ValueKey(error), crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.error_outline_sharp, size: 16, color: C.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text.rich(TextSpan(style: T.caption.copyWith(fontSize: 12.5, color: C.danger, fontWeight: FontWeight.w600), children: [
                              TextSpan(text: error),
                              if (_ownNumber)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RechargeScreen())),
                                    child: BrandShade(
                                      child:
                                          Text('  Recharge your TVs ›', style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand)),
                                    ),
                                  ),
                                ),
                            ])),
                          ),
                        ]),
                ),
                // Numbers you've looked up, for a quick repeat.
                ValueListenableBuilder<List<(String, String)>>(
                  valueListenable: _recent,
                  builder: (context, recent, _) => recent.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: S.xl),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('RECENT', style: T.overline),
                            const SizedBox(height: S.sm),
                            for (final r in recent)
                              InkWell(
                                onTap: () {
                                  _number.text = r.$1;
                                  _find();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(children: [
                                    Avatar(initials: r.$2.split(' ').map((w) => w[0]).take(2).join(), size: 34),
                                    const SizedBox(width: S.md),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(r.$2, style: T.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                                        Text('+91 ${_pretty(r.$1)}', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                                      ]),
                                    ),
                                    Icon(Icons.chevron_right_sharp, size: 20, color: C.faint),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                ),
                Container(height: 1, margin: const EdgeInsets.symmetric(vertical: S.xl), color: C.line),
                Text('WHY PAY FOR SOMEONE', style: T.overline),
                const SizedBox(height: S.md),
                _why(Icons.people_alt_outlined, 'Recharge ', 'any DishTV connection', ' from your account'),
                _why(Icons.notifications_none_sharp, 'They get an ', 'SMS', ' as soon as it\'s done'),
                _why(Icons.calendar_today_outlined, 'Pay for ', '1 to 12 months', ' in one go'),
              ],
            ),
          ),
          BottomBar(
            child: PrimaryButton(label: 'Find connection', busy: _busy, onTap: _complete && !_busy ? _find : null),
          ),
        ]),
      ),
    );
  }

  Widget _why(IconData icon, String a, String b, String c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BrandShade(child: Icon(icon, size: 21, color: C.brand)),
          const SizedBox(width: S.md),
          Expanded(
            child: Text.rich(TextSpan(style: T.body.copyWith(fontSize: 14, color: C.inkSoft), children: [
              TextSpan(text: a),
              TextSpan(text: b, style: T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: c),
            ])),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Connection details

class _DetailsScreen extends StatelessWidget {
  const _DetailsScreen({required this.c, required this.mobile});
  final Connection c;
  final String mobile;

  @override
  Widget build(BuildContext context) {
    final off = c.daysLeft(DateTime.now()) <= 0;
    const soft = Color(0xD9FFFFFF);
    Widget figure(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.overline.copyWith(fontSize: 10.5, color: soft)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: T.price.copyWith(fontSize: 24, color: Colors.white))),
        ]);
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Text(a, style: T.body.copyWith(fontSize: 14, color: C.muted)),
            const SizedBox(width: S.lg),
            Expanded(child: Text(b, textAlign: TextAlign.end, style: T.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700))),
          ]),
        );
    // Only part of their number is shown back.
    final masked = '+91 ${mobile.substring(0, 2)}xxx xx${mobile.substring(7)}';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Connection Details'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              children: [
                Row(children: [
                  Expanded(child: Text('CONNECTION FOUND', style: T.overline)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: C.success.withValues(alpha: 0.14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_sharp, size: 15, color: C.success),
                      const SizedBox(width: 4),
                      Text('Verified', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.success)),
                    ]),
                  ),
                ]),
                const SizedBox(height: S.md),
                // Who and how much, on the card gradient.
                Reveal(
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(gradient: G.brand),
                    child: Stack(children: [
                      const Positioned.fill(child: GlossSweep()),
                      Padding(
                        padding: const EdgeInsets.all(S.lg + 2),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              color: const Color(0x29FFFFFF),
                              child: const Icon(Icons.tv_sharp, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: S.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 18, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text('VC No. ${c.vcPretty}', style: T.caption.copyWith(fontSize: 12.5, color: soft)),
                              ]),
                            ),
                          ]),
                          Container(height: 1, margin: const EdgeInsets.symmetric(vertical: S.lg), color: const Color(0x33FFFFFF)),
                          IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(child: figure(off ? 'SWITCHED OFF ON' : 'NEXT RECHARGE', _short(c.switchOffDate))),
                              Container(width: 1, margin: const EdgeInsets.only(right: S.lg), color: const Color(0x40FFFFFF)),
                              Expanded(child: figure('RECHARGE', rupees(c.monthlyRecharge))),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: S.sm),
                Reveal(
                  order: 1,
                  child: Column(children: [
                    row('Current pack', c.planName),
                    Container(height: 1, color: C.line),
                    row('Connection', 'DishTV · Single TV${c.isHd ? ' · HD' : ''}'),
                    Container(height: 1, color: C.line),
                    row('Registered mobile', masked),
                  ]),
                ),
                if (off) ...[
                  const SizedBox(height: S.md),
                  Container(
                    padding: const EdgeInsets.all(S.md),
                    color: C.warning.withValues(alpha: 0.12),
                    child: Row(children: [
                      Icon(Icons.power_off_outlined, size: 20, color: C.warning),
                      const SizedBox(width: S.sm),
                      Expanded(
                        child: Text('This TV is switched off. Recharging switches it back on.', style: T.label.copyWith(fontSize: 13, color: C.warning)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: S.lg),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lock_outline_sharp, size: 16, color: C.muted),
                  const SizedBox(width: S.sm),
                  Expanded(child: Text('Your payment will be applied to this connection only.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted))),
                ]),
              ],
            ),
          ),
          BottomBar(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrimaryButton(
                label: 'Continue to Recharge',
                icon: Icons.arrow_forward_sharp,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RechargeScreen(other: c, mobile: mobile))),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Not them? Change number', style: T.label.copyWith(fontSize: 13, color: C.muted)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
