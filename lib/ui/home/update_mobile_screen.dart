// Update Mobile No.: shows the registered number (masked), and "Change
// number" opens a field for the new one. "Send OTP" opens a sheet with six
// boxes and a resend countdown; any six digits verify it (000000 shows the
// wrong-OTP message). The new number is saved to the profile and a
// confirmation shows what moved to it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../state/app_store.dart';
import '../widgets/showtime.dart';
import '../widgets/widgets.dart';
import 'support_screen.dart' show ContactSupportScreen;

String _pretty(String m) => m.length == 10 ? '${m.substring(0, 5)} ${m.substring(5)}' : m;
String _masked(String m) => m.length < 2 ? m : '${'X' * (m.length - 2)}${m.substring(m.length - 2)}';

class UpdateMobileScreen extends StatefulWidget {
  const UpdateMobileScreen({super.key});

  @override
  State<UpdateMobileScreen> createState() => _UpdateMobileScreenState();
}

class _UpdateMobileScreenState extends State<UpdateMobileScreen> {
  final _number = TextEditingController();
  final _focus = FocusNode();
  bool _changing = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _number.addListener(() => setState(() => _error = null));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _number.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startChange() {
    HapticFeedback.selectionClick();
    setState(() => _changing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _cancel() {
    _focus.unfocus();
    _number.clear();
    setState(() {
      _changing = false;
      _error = null;
    });
  }

  Future<void> _sendOtp(String current) async {
    final m = _number.text;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(m)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (m == current) {
      setState(() => _error = 'That\'s already your registered number.');
      return;
    }
    _focus.unfocus();
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _sending = false);
    final ok = await showSheet<bool>(
      context,
      title: 'Verify mobile number',
      subtitle: 'We\'ve sent a 6-digit OTP to +91 ${_pretty(m)}',
      builder: (_) => const _OtpSheet(),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppStore>();
    final sub = app.subscriber;
    if (sub == null) return;
    await app.updateProfile(sub.copyWith(mobile: m));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => _Updated(old: current, now: m),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AppStore>().subscriber?.mobile ?? '';
    final error = _error;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Update Mobile No.'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text('Your registered mobile number', style: T.title.copyWith(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: S.lg),
                // The number on file, masked.
                Reveal(
                  child: Container(
                    color: C.surface,
                    padding: const EdgeInsets.all(S.lg),
                    child: Row(children: [
                      Container(width: 46, height: 46, color: C.sunken, child: Icon(Icons.call_outlined, size: 22, color: C.ink)),
                      const SizedBox(width: S.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Current number', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_masked(current), style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 2)),
                          ),
                        ]),
                      ),
                      const _Verified(),
                    ]),
                  ),
                ),
                const SizedBox(height: S.md),
                Text('OTPs, recharge alerts and bills are sent to this number.', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                // The new number, once "Change number" is tapped.
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_changing
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: S.xxl),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('NEW MOBILE NUMBER', style: T.overline),
                            const SizedBox(height: S.md),
                            Text('Mobile number', style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.inkSoft)),
                            const SizedBox(height: S.sm),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 56,
                              padding: const EdgeInsets.only(left: S.lg),
                              decoration: BoxDecoration(
                                color: C.surface,
                                border: Border.all(color: error != null ? C.danger : (_focus.hasFocus ? C.brand : C.surface), width: 1.2),
                              ),
                              child: Row(children: [
                                Text('+91', style: T.item.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: C.inkSoft)),
                                Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: S.md), color: C.lineStrong),
                                Expanded(
                                  child: TextField(
                                    controller: _number,
                                    focusNode: _focus,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.telephoneNumberNational],
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                    onSubmitted: (_) => _number.text.length == 10 ? _sendOtp(current) : null,
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
                            error == null
                                ? Text('We\'ll send an OTP to this number to verify it', style: T.caption.copyWith(fontSize: 12.5, color: C.muted))
                                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(Icons.error_outline_sharp, size: 16, color: C.danger),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(error, style: T.caption.copyWith(fontSize: 12.5, color: C.danger, fontWeight: FontWeight.w600))),
                                  ]),
                          ]),
                        ),
                ),
              ],
            ),
          ),
          BottomBar(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!_changing)
                PrimaryButton(label: 'Change number', onTap: _startChange)
              else ...[
                PrimaryButton(label: 'Send OTP', busy: _sending, onTap: _number.text.length == 10 && !_sending ? () => _sendOtp(current) : null),
                TextButton(onPressed: _sending ? null : _cancel, child: Text('Keep current number', style: T.label.copyWith(fontSize: 13, color: C.muted))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: C.success.withValues(alpha: 0.14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_sharp, size: 15, color: C.success),
          const SizedBox(width: 4),
          Text('Verified', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.success)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// OTP

/// Six boxes over one hidden field, a resend countdown, and Verify &
/// Update. Closes with true once the OTP checks out.
class _OtpSheet extends StatefulWidget {
  const _OtpSheet();

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  static const _length = 6;
  static const _wait = 30;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _tick;
  int _left = _wait;
  bool _verifying = false;
  String? _error;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _startTimer() {
    _tick?.cancel();
    _left = _wait;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _resend() {
    HapticFeedback.selectionClick();
    _code.clear();
    setState(() {
      _resent = true;
      _startTimer();
    });
    _focus.requestFocus();
  }

  Future<void> _verify() async {
    _focus.unfocus();
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    if (_code.text == '000000') {
      HapticFeedback.heavyImpact();
      setState(() {
        _verifying = false;
        _error = 'That OTP isn\'t right. Check the SMS and try again.';
      });
      _code.clear();
      _focus.requestFocus();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final code = _code.text;
    final error = _error;
    final mq = MediaQuery.of(context);
    return Padding(
      // Rides up above the keyboard.
      padding: EdgeInsets.fromLTRB(S.page, S.md, S.page, S.xl + mq.viewInsets.bottom + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 58,
          child: Stack(children: [
            Row(children: [
              for (var i = 0; i < _length; i++) ...[
                if (i > 0) const SizedBox(width: S.sm),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.surface,
                      border: Border.all(
                        color: error != null ? C.danger : (i == code.length && _focus.hasFocus ? C.brand : (i < code.length ? C.lineStrong : C.surface)),
                        width: 1.4,
                      ),
                    ),
                    child: Text(i < code.length ? code[i] : '', style: T.title.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
            // The real field: invisible, on top, so a tap anywhere types.
            Positioned.fill(
              child: Opacity(
                opacity: 0.011,
                child: TextField(
                  controller: _code,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_length)],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  // The boxes show the digits; the field's own text stays invisible.
                  style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  onChanged: (v) {
                    if (v.length == _length) HapticFeedback.selectionClick();
                  },
                  onSubmitted: (_) => code.length == _length ? _verify() : null,
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: S.md),
        Row(children: [
          Expanded(
            child: error != null
                ? Text(error, style: T.caption.copyWith(fontSize: 12.5, color: C.danger, fontWeight: FontWeight.w600))
                : Text(_resent ? 'A new OTP is on its way' : 'Use any 6 digits', style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
          ),
          const SizedBox(width: S.md),
          if (_left > 0)
            Text('Resend OTP in 0:${_left.toString().padLeft(2, '0')}', style: T.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.inkSoft))
          else
            InkWell(
              onTap: _resend,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: BrandShade(child: Text('Resend OTP', style: T.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: C.brand))),
              ),
            ),
        ]),
        const SizedBox(height: S.xl),
        PrimaryButton(label: 'Verify & Update', busy: _verifying, onTap: code.length == _length && !_verifying ? _verify : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Success

class _Updated extends StatefulWidget {
  const _Updated({required this.old, required this.now});
  final String old;
  final String now;

  @override
  State<_Updated> createState() => _UpdatedState();
}

class _UpdatedState extends State<_Updated> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _fade(double from, Widget child) {
    final c = CurvedAnimation(parent: _a, curve: Interval(from, (from + 0.3).clamp(0, 1), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: c, child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c), child: child));
  }

  @override
  Widget build(BuildContext context) {
    Widget moved(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Icon(icon, size: 20, color: C.ink),
            const SizedBox(width: S.md),
            Expanded(child: Text(text, style: T.body.copyWith(fontSize: 14, color: C.inkSoft))),
            Icon(Icons.check_sharp, size: 18, color: C.success),
          ]),
        );
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.page, 44, S.page, S.xl),
                children: [
                  // A phone on the card gradient with a green tick landing on it.
                  Center(
                    child: SizedBox(
                      width: 120,
                      height: 112,
                      child: Stack(alignment: Alignment.center, children: [
                        ScaleTransition(
                          scale: CurvedAnimation(parent: _a, curve: const Interval(0, 0.4, curve: Curves.elasticOut)),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: const BoxDecoration(gradient: G.brand),
                            child: const Icon(Icons.smartphone_sharp, color: Colors.white, size: 46),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: ScaleTransition(
                            scale: CurvedAnimation(parent: _a, curve: const Interval(0.25, 0.6, curve: Curves.elasticOut)),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: C.success, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 3)),
                              child: const Icon(Icons.check_sharp, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: S.lg),
                  _fade(
                    0.25,
                    Column(children: [
                      Text('Mobile number updated', textAlign: TextAlign.center, style: T.display),
                      const SizedBox(height: 6),
                      Text('Your account now uses +91 ${_pretty(widget.now)}.', textAlign: TextAlign.center, style: T.body),
                    ]),
                  ),
                  const SizedBox(height: S.xxl),
                  // Old number out, new number in.
                  _fade(
                    0.38,
                    Container(
                      color: C.surface,
                      padding: const EdgeInsets.all(S.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Old number', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                        const SizedBox(height: 2),
                        Text(_masked(widget.old),
                            style: T.label
                                .copyWith(fontSize: 15, letterSpacing: 1.5, color: C.muted, decoration: TextDecoration.lineThrough, decorationColor: C.muted)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: S.sm),
                          child: BrandShade(child: Icon(Icons.south_sharp, size: 20, color: C.brand)),
                        ),
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('New number', style: T.caption.copyWith(fontSize: 12, color: C.muted)),
                              const SizedBox(height: 2),
                              Text('+91 ${_pretty(widget.now)}', style: T.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const _Verified(),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: S.xl),
                  _fade(
                    0.5,
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('NOW SENT TO YOUR NEW NUMBER', style: T.overline),
                      const SizedBox(height: S.sm),
                      moved(Icons.password_sharp, 'OTPs to sign in and confirm payments'),
                      moved(Icons.notifications_none_sharp, 'Recharge alerts and reminders'),
                      moved(Icons.receipt_long_outlined, 'Bills and account statements'),
                    ]),
                  ),
                  const SizedBox(height: S.lg),
                  _fade(
                    0.6,
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.shield_outlined, size: 16, color: C.muted),
                      const SizedBox(width: S.sm),
                      Expanded(
                        child: Text.rich(TextSpan(style: T.caption.copyWith(fontSize: 12.5, color: C.muted), children: [
                          const TextSpan(text: 'Didn\'t make this change? '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                              child: BrandShade(
                                  child: Text('Contact support', style: T.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand))),
                            ),
                          ),
                          const TextSpan(text: ' right away.'),
                        ])),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg), child: PrimaryButton(label: 'Done', onTap: () => Navigator.of(context).pop())),
          ]),
        ),
        const Positioned.fill(child: Confetti()),
      ]),
    );
  }
}
