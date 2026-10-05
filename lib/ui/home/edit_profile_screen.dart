// Edit Profile: name, mobile, email and the installation address in parts.
//
// Outlined, sharp fields that turn orange when focused. Save Changes is
// enabled once something changes; problems show under the field after the
// first try. A new mobile number is confirmed by OTP.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_store.dart';
import '../widgets/widgets.dart';
import 'photo_editor_screen.dart';

const _states = [
  'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh', //
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', //
  'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', //
  'Mizoram', 'Nagaland', 'Odisha', 'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', //
  'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Subscriber _orig = context.read<AppStore>().subscriber!;
  late final _name = TextEditingController(text: _orig.name);
  late final _mobile = TextEditingController(text: _orig.mobile);
  late final _email = TextEditingController(text: _orig.email);
  late final _house = TextEditingController(text: _orig.address.house);
  late final _street = TextEditingController(text: _orig.address.street);
  late final _landmark = TextEditingController(text: _orig.address.landmark);
  late final _city = TextEditingController(text: _orig.address.city);
  late final _pincode = TextEditingController(text: _orig.address.pincode);
  late String _state = _orig.address.state;

  /// The photo being edited, and the original it was framed from (so
  /// "Edit current photo" can re-frame without losing detail).
  late Uint8List? _photo = _orig.photo;
  Uint8List? _photoSource;

  bool _tried = false;
  bool _saving = false;

  List<TextEditingController> get _all => [_name, _mobile, _email, _house, _street, _landmark, _city, _pincode];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Subscriber get _draft => _orig.copyWith(
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim(),
        address: Address(
          house: _house.text.trim(),
          street: _street.text.trim(),
          landmark: _landmark.text.trim(),
          city: _city.text.trim(),
          pincode: _pincode.text.trim(),
          state: _state,
        ),
        photo: _photo,
        removePhoto: _photo == null,
      );

  bool get _dirty {
    final d = _draft, o = _orig;
    return d.name != o.name ||
        d.mobile != o.mobile ||
        d.email != o.email ||
        d.address.oneLine != o.address.oneLine ||
        d.address.house != o.address.house ||
        d.address.street != o.address.street ||
        d.address.landmark != o.address.landmark ||
        !identical(_photo, o.photo);
  }

  // ------------------------------------------------------------- photo

  Future<void> _changePhoto() async {
    final has = _photo != null;
    final choice = await showSheet<String>(
      context,
      title: 'Profile photo',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _photoOption(ctx, Icons.photo_camera_outlined, 'Take a photo', 'camera'),
        _photoOption(ctx, Icons.photo_library_outlined, 'Choose from gallery', 'gallery'),
        if (has) _photoOption(ctx, Icons.crop_rounded, 'Edit current photo', 'edit'),
        if (has) _photoOption(ctx, Icons.delete_outline_rounded, 'Remove photo', 'remove', danger: true),
        SizedBox(height: S.md + MediaQuery.paddingOf(ctx).bottom),
      ]),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
      case 'gallery':
        await _pick(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
      case 'edit':
        await _frame(_photoSource ?? _photo!);
      case 'remove':
        setState(() {
          _photo = null;
          _photoSource = null;
        });
    }
  }

  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _frame(bytes);
    } on PlatformException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(source == ImageSource.camera
              ? "Couldn't open the camera. Allow camera access for DishTV in Settings."
              : "Couldn't open your photos. Allow photo access for DishTV in Settings."),
        ));
    }
  }

  Future<void> _frame(Uint8List source) async {
    final out = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => PhotoEditorScreen(bytes: source)));
    if (out != null && mounted) {
      setState(() {
        _photo = out;
        _photoSource = source;
      });
    }
  }

  Widget _photoOption(BuildContext ctx, IconData icon, String label, String value, {bool danger = false}) => Semantics(
        container: true,
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => Navigator.of(ctx).pop(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: S.page, vertical: 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: Row(children: [
                Icon(icon, size: 22, color: danger ? C.danger : C.brand),
                const SizedBox(width: S.lg),
                Expanded(child: Text(label, style: T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: danger ? C.danger : C.ink))),
              ]),
            ),
          ),
        ),
      );

  // Validation: null means fine.
  String? get _nameErr => _name.text.trim().length < 2 ? 'Enter your full name' : null;
  String? get _mobileErr => RegExp(r'^[6-9]\d{9}$').hasMatch(_mobile.text.trim()) ? null : 'Enter a 10-digit mobile number';
  String? get _emailErr {
    final e = _email.text.trim();
    if (e.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e) ? null : 'Enter a valid email address';
  }

  String? get _houseErr => _house.text.trim().isEmpty ? 'Enter your house or flat number' : null;
  String? get _streetErr => _street.text.trim().isEmpty ? 'Enter the street or area' : null;
  String? get _cityErr => _city.text.trim().isEmpty ? 'Enter your city' : null;
  String? get _pincodeErr => RegExp(r'^[1-9]\d{5}$').hasMatch(_pincode.text.trim()) ? null : 'Enter a 6-digit pincode';
  String? get _stateErr => _state.isEmpty ? 'Choose your state' : null;

  bool get _valid => [_nameErr, _mobileErr, _emailErr, _houseErr, _streetErr, _cityErr, _pincodeErr, _stateErr].every((e) => e == null);

  // One key per field, so Save can scroll to the first problem.
  final _keys = {
    for (final k in ['name', 'mobile', 'email', 'house', 'street', 'city', 'pincode', 'state']) k: GlobalKey()
  };

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_valid) {
      // Errors show under each field; bring the first one into view.
      final first = {
        'name': _nameErr,
        'mobile': _mobileErr,
        'email': _emailErr,
        'house': _houseErr,
        'street': _streetErr,
        'city': _cityErr,
        'pincode': _pincodeErr,
        'state': _stateErr,
      }.entries.firstWhere((e) => e.value != null).key;
      HapticFeedback.mediumImpact();
      final ctx = _keys[first]!.currentContext;
      if (ctx != null) await Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 250));
      return;
    }
    setState(() => _saving = true);
    final newNumber = _draft.mobile != _orig.mobile;
    final app = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await app.updateProfile(_draft);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(newNumber ? 'Profile updated. We\'ll send an OTP to +91 ${_draft.mobilePretty} to confirm the new number.' : 'Profile updated.'),
      ));
    nav.pop();
  }

  Future<void> _pickState() async {
    final picked = await showSheet<String>(
      context,
      title: 'Choose your state',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: S.lg + MediaQuery.paddingOf(ctx).bottom),
        children: [
          for (final st in _states)
            Semantics(
              container: true,
              button: true,
              selected: st == _state,
              label: st,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(st),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: S.page, vertical: 14),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                    child: Row(children: [
                      Expanded(child: Text(st, style: T.body.copyWith(fontSize: 14, color: st == _state ? C.brand : C.ink, fontWeight: FontWeight.w600))),
                      if (st == _state) const Icon(Icons.check_rounded, color: C.brand, size: 20),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _state = picked);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final stackCityPin = mq.size.width < 360 || mq.textScaler.scale(10) > 13;
    final city = _Field(
      key: const ValueKey('field-city'),
      anchor: _keys['city'],
      label: 'City',
      controller: _city,
      error: _tried ? _cityErr : null,
      textInputAction: TextInputAction.next,
      capitalization: TextCapitalization.words,
    );
    final pin = _Field(
      key: const ValueKey('field-pincode'),
      anchor: _keys['pincode'],
      label: 'Pincode',
      controller: _pincode,
      error: _tried ? _pincodeErr : null,
      keyboard: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Edit Profile'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xxl),
              children: [
                _photoHeader(),
                const SizedBox(height: S.lg),
                _Field(
                  key: const ValueKey('field-name'),
                  anchor: _keys['name'],
                  label: 'Full Name',
                  controller: _name,
                  error: _tried ? _nameErr : null,
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                _Field(
                  key: const ValueKey('field-mobile'),
                  anchor: _keys['mobile'],
                  label: 'Mobile Number',
                  controller: _mobile,
                  prefix: '+91',
                  error: _tried ? _mobileErr : null,
                  help: 'Changing your number needs OTP verification',
                  keyboard: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                ),
                _Field(
                  key: const ValueKey('field-email'),
                  anchor: _keys['email'],
                  label: 'Email',
                  controller: _email,
                  error: _tried ? _emailErr : null,
                  keyboard: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: S.sm),
                const Divider(height: 1, color: C.line),
                Padding(
                  padding: const EdgeInsets.only(top: S.xl, bottom: S.md),
                  child: Row(children: [
                    Container(width: 3, height: 14, color: C.brand),
                    const SizedBox(width: S.sm),
                    Semantics(header: true, child: Text('ADDRESS', style: T.overline.copyWith(fontSize: 12, color: C.inkSoft))),
                  ]),
                ),
                _Field(
                  key: const ValueKey('field-house'),
                  anchor: _keys['house'],
                  label: 'House / Flat no., Building',
                  controller: _house,
                  error: _tried ? _houseErr : null,
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                _Field(
                  key: const ValueKey('field-street'),
                  anchor: _keys['street'],
                  label: 'Street, Area / Locality',
                  controller: _street,
                  error: _tried ? _streetErr : null,
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                _Field(
                  key: const ValueKey('field-landmark'),
                  label: 'Landmark',
                  optional: true,
                  controller: _landmark,
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                if (stackCityPin) ...[city, pin] else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: city), const SizedBox(width: S.md), Expanded(child: pin)]),
                _statePicker(),
              ],
            ),
          ),
          BottomBar(
            child: PrimaryButton(
              label: 'Save Changes',
              busy: _saving,
              onTap: _dirty ? _save : null,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoHeader() {
    final sub = _draft;
    return Column(children: [
      Semantics(
        container: true,
        button: true,
        label: _photo == null ? 'Add a profile photo' : 'Change profile photo',
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: _changePhoto,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(clipBehavior: Clip.none, children: [
                Avatar(initials: sub.initials, photo: _photo, size: 96),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: C.brand, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 3)),
                    child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: _changePhoto,
        child: Text(_photo == null ? 'Add Photo' : 'Change Photo', style: T.label.copyWith(color: C.brand)),
      ),
    ]);
  }

  Widget _statePicker() {
    final err = _tried ? _stateErr : null;
    return Padding(
      key: _keys['state'],
      padding: const EdgeInsets.only(bottom: S.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('State', style: _Field.labelStyle),
        const SizedBox(height: 6),
        Semantics(
          container: true,
          button: true,
          label: 'State, ${_state.isEmpty ? 'not chosen' : _state}',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: _pickState,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: err != null ? C.danger : C.lineStrong)),
                child: Row(children: [
                  Expanded(child: Text(_state.isEmpty ? 'Choose your state' : _state, style: _state.isEmpty ? _Field.hintStyle : _Field.valueStyle)),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: C.muted),
                ]),
              ),
            ),
          ),
        ),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(err, style: _Field.errorStyle)),
      ]),
    );
  }
}

/// A labelled, outlined text field. Orange border when focused, red when
/// there's a problem; help or the problem shows underneath.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.help,
    this.prefix,
    this.optional = false,
    this.keyboard,
    this.textInputAction,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.anchor,
  });

  /// Lets the screen scroll this field into view.
  final GlobalKey? anchor;

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? help;
  final String? prefix;
  final bool optional;
  final TextInputType? keyboard;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;

  static final labelStyle = T.caption.copyWith(fontSize: 12.5, color: C.inkSoft, fontWeight: FontWeight.w600);
  static final valueStyle = T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w600);
  static final hintStyle = T.body.copyWith(fontSize: 14, color: C.faint);
  static final errorStyle = T.caption.copyWith(fontSize: 12, color: C.danger, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));
    return Padding(
      key: anchor,
      padding: const EdgeInsets.only(bottom: S.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: label, style: labelStyle),
          if (optional) TextSpan(text: ' (optional)', style: labelStyle.copyWith(color: C.muted, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          textInputAction: textInputAction,
          inputFormatters: formatters,
          textCapitalization: capitalization,
          style: valueStyle,
          cursorColor: C.brand,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(prefix!, style: valueStyle.copyWith(color: C.inkSoft)),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 20, color: C.lineStrong),
                    ]),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            enabledBorder: border(error != null ? C.danger : C.lineStrong),
            focusedBorder: border(error != null ? C.danger : C.brand, 1.5),
            border: border(C.lineStrong),
          ),
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: errorStyle))
        else if (help != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(help!, style: T.caption.copyWith(fontSize: 12))),
      ]),
    );
  }
}
