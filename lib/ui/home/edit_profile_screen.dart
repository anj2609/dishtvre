// Edit Profile: photo, name, mobile, email and the installation address.
//
// A header card previews the name and shows how complete the profile is.
// Outlined, sharp fields with icons that turn orange when focused and a tick
// once a change is valid. Save Changes is enabled once something changes,
// with a count of unsaved changes and Discard; leaving with unsaved changes
// asks first. Photos come from the camera, the gallery or files, then go
// through the photo editor. A new mobile number is confirmed by OTP.

import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
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

  bool get _dirty => _changes.isNotEmpty;

  // ------------------------------------------------------------- photo

  Future<void> _changePhoto() async {
    final has = _photo != null;
    final choice = await showSheet<String>(
      context,
      title: 'Profile photo',
      subtitle: 'Take one now, or pick from your gallery or files',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.lg),
          child: Row(children: [
            Expanded(child: _sourceTile(ctx, Icons.photo_camera_outlined, 'Camera', 'camera', 'Take a photo with the camera')),
            const SizedBox(width: S.sm),
            Expanded(child: _sourceTile(ctx, Icons.photo_library_outlined, 'Gallery', 'gallery', 'Choose from your gallery')),
            const SizedBox(width: S.sm),
            Expanded(child: _sourceTile(ctx, Icons.folder_open_outlined, 'Files', 'files', 'Choose an image file')),
          ]),
        ),
        if (has) ...[
          Divider(height: 1, color: C.line),
          _photoOption(ctx, Icons.crop_sharp, 'Edit current photo', 'edit'),
          _photoOption(ctx, Icons.delete_outline_sharp, 'Remove photo', 'remove', danger: true),
        ],
        SizedBox(height: S.md + MediaQuery.paddingOf(ctx).bottom),
      ]),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _pick(ImageSource.camera);
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'files':
        await _pickFile();
      case 'edit':
        await _frame(_photoSource ?? _photo!);
      case 'remove':
        setState(() {
          _photo = null;
          _photoSource = null;
        });
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null || !mounted) return;
      await _open(await file.readAsBytes());
    } on PlatformException {
      if (!mounted) return;
      _say(source == ImageSource.camera
          ? "Couldn't open the camera. Allow camera access for DishTV in Settings."
          : "Couldn't open your photos. Allow photo access for DishTV in Settings.");
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      final bytes = result?.files.single.bytes;
      if (bytes == null || !mounted) return;
      if (bytes.lengthInBytes > 15 * 1024 * 1024) {
        _say('That file is too large. Choose an image under 15 MB.');
        return;
      }
      await _open(bytes);
    } on PlatformException {
      if (!mounted) return;
      _say("Couldn't open your files. Allow file access for DishTV in Settings.");
    }
  }

  /// Checks the bytes are an image we can show, then opens the editor.
  Future<void> _open(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      codec.dispose();
    } catch (_) {
      if (mounted) _say("That file isn't a photo we can open. Try a JPG or PNG.");
      return;
    }
    if (mounted) await _frame(bytes);
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

  // A big square choice: icon over its name.
  Widget _sourceTile(BuildContext ctx, IconData icon, String label, String value, String semantics) => Semantics(
        container: true,
        button: true,
        label: semantics,
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            shape: RoundedRectangleBorder(side: BorderSide(color: C.lineStrong)),
            child: InkWell(
              onTap: () => Navigator.of(ctx).pop(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.lg, horizontal: S.sm),
                child: Column(children: [
                  BrandShade(child: Icon(icon, size: 28, color: C.brand)),
                  const SizedBox(height: S.sm),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: T.label.copyWith(fontSize: 13.5))),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _photoOption(BuildContext ctx, IconData icon, String label, String value, {bool danger = false}) => Semantics(
        container: true,
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => Navigator.of(ctx).pop(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: S.page, vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: Row(children: [
                Icon(icon, size: 22, color: danger ? C.danger : C.ink),
                const SizedBox(width: S.lg),
                Expanded(child: Text(label, style: T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: danger ? C.danger : C.ink))),
              ]),
            ),
          ),
        ),
      );

  // ------------------------------------------------- changes & completeness

  /// What has changed, by field, for the "unsaved changes" count.
  List<String> get _changes {
    final d = _draft, o = _orig, a = d.address, b = o.address;
    return [
      if (!identical(_photo, o.photo)) 'photo',
      if (d.name != o.name) 'name',
      if (d.mobile != o.mobile) 'mobile',
      if (d.email != o.email) 'email',
      if (a.house != b.house) 'house',
      if (a.street != b.street) 'street',
      if (a.landmark != b.landmark) 'landmark',
      if (a.city != b.city) 'city',
      if (a.pincode != b.pincode) 'pincode',
      if (a.state != b.state) 'state',
    ];
  }

  void _discard() => setState(() {
        _name.text = _orig.name;
        _mobile.text = _orig.mobile;
        _email.text = _orig.email;
        _house.text = _orig.address.house;
        _street.text = _orig.address.street;
        _landmark.text = _orig.address.landmark;
        _city.text = _orig.address.city;
        _pincode.text = _orig.address.pincode;
        _state = _orig.address.state;
        _photo = _orig.photo;
        _photoSource = null;
        _tried = false;
      });

  /// Share of the profile filled in, and what to add next.
  (double, String?) get _completeness {
    final checks = <(bool, String)>[
      (_nameErr == null, 'Add your full name'),
      (_mobileErr == null, 'Add your mobile number'),
      (_email.text.trim().isNotEmpty && _emailErr == null, 'Add an email for bills and statements'),
      (_houseErr == null && _streetErr == null, 'Add your house and street'),
      (_cityErr == null && _pincodeErr == null && _stateErr == null, 'Add your city, pincode and state'),
      (_landmark.text.trim().isNotEmpty, 'Add a landmark to help our technician find you'),
      (_photo != null, 'Add a photo'),
    ];
    final done = checks.where((c) => c.$1).length;
    return (done / checks.length, checks.where((c) => !c.$1).map((c) => c.$2).firstOrNull);
  }

  Future<bool> _confirmDiscard() async {
    final n = _changes.length;
    final discard = await showSheet<bool>(
      context,
      title: 'Discard changes?',
      subtitle: 'You have $n unsaved ${n == 1 ? 'change' : 'changes'}.',
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.lg + MediaQuery.paddingOf(ctx).bottom),
        child: Row(children: [
          Expanded(child: SecondaryButton(label: 'Keep editing', onTap: () => Navigator.of(ctx).pop(false))),
          const SizedBox(width: S.md),
          Expanded(child: PrimaryButton(label: 'Discard changes', onTap: () => Navigator.of(ctx).pop(true))),
        ]),
      ),
    );
    return discard ?? false;
  }

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
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                    child: Row(children: [
                      Expanded(child: BrandShade(on: st == _state, child: Text(st, style: T.body.copyWith(fontSize: 14, color: st == _state ? C.brand : C.ink, fontWeight: FontWeight.w600)))),
                      if (st == _state) BrandShade(child: Icon(Icons.check_sharp, color: C.brand, size: 20)),
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

  /// A field's tick: shown once it differs from what was saved and is valid.
  bool _ok(String key, String? err) => _changes.contains(key) && err == null;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final stackCityPin = mq.size.width < 360 || mq.textScaler.scale(10) > 13;
    final city = _Field(
      key: const ValueKey('field-city'),
      anchor: _keys['city'],
      icon: Icons.location_city_outlined,
      label: 'City',
      controller: _city,
      error: _tried ? _cityErr : null,
      ok: _ok('city', _cityErr),
      textInputAction: TextInputAction.next,
      capitalization: TextCapitalization.words,
    );
    final pin = _Field(
      key: const ValueKey('field-pincode'),
      anchor: _keys['pincode'],
      icon: Icons.markunread_mailbox_outlined,
      label: 'Pincode',
      controller: _pincode,
      error: _tried ? _pincodeErr : null,
      ok: _ok('pincode', _pincodeErr),
      keyboard: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
    );
    final changes = _changes.length;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard() && mounted) nav.pop();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Header(title: 'Edit Profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.xxl),
                children: [
                  _photoHeader(),
                  const _Section('PERSONAL DETAILS'),
                  _Field(
                    key: const ValueKey('field-name'),
                    anchor: _keys['name'],
                    icon: Icons.person_outline_sharp,
                    label: 'Full Name',
                    controller: _name,
                    error: _tried ? _nameErr : null,
                    ok: _ok('name', _nameErr),
                    textInputAction: TextInputAction.next,
                    capitalization: TextCapitalization.words,
                  ),
                  const _Section('CONTACT'),
                  _Field(
                    key: const ValueKey('field-mobile'),
                    anchor: _keys['mobile'],
                    icon: Icons.call_outlined,
                    label: 'Mobile Number',
                    controller: _mobile,
                    prefix: '+91',
                    error: _tried ? _mobileErr : null,
                    ok: _ok('mobile', _mobileErr),
                    help: 'Changing your number needs OTP verification',
                    keyboard: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  ),
                  _Field(
                    key: const ValueKey('field-email'),
                    anchor: _keys['email'],
                    icon: Icons.mail_outline_sharp,
                    label: 'Email',
                    controller: _email,
                    error: _tried ? _emailErr : null,
                    ok: _ok('email', _emailErr),
                    help: 'Bills and statements are sent here',
                    keyboard: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const _Section('ADDRESS'),
                  _Field(
                    key: const ValueKey('field-house'),
                    anchor: _keys['house'],
                    icon: Icons.home_outlined,
                    label: 'House / Flat no., Building',
                    controller: _house,
                    error: _tried ? _houseErr : null,
                    ok: _ok('house', _houseErr),
                    textInputAction: TextInputAction.next,
                    capitalization: TextCapitalization.words,
                  ),
                  _Field(
                    key: const ValueKey('field-street'),
                    anchor: _keys['street'],
                    icon: Icons.signpost_outlined,
                    label: 'Street, Area / Locality',
                    controller: _street,
                    error: _tried ? _streetErr : null,
                    ok: _ok('street', _streetErr),
                    textInputAction: TextInputAction.next,
                    capitalization: TextCapitalization.words,
                  ),
                  _Field(
                    key: const ValueKey('field-landmark'),
                    icon: Icons.place_outlined,
                    label: 'Landmark',
                    optional: true,
                    controller: _landmark,
                    ok: _ok('landmark', null) && _landmark.text.trim().isNotEmpty,
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
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // How many changes are waiting, with a way to undo them all.
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: changes == 0
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: S.sm),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(gradient: G.brand)),
                            const SizedBox(width: S.sm),
                            Expanded(child: Text('$changes unsaved ${changes == 1 ? 'change' : 'changes'}', style: T.label.copyWith(fontSize: 13))),
                            TextButton(
                              onPressed: _saving ? null : _discard,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: S.sm),
                                minimumSize: const Size(0, 36),
                                shape: const RoundedRectangleBorder(),
                              ),
                              child: BrandShade(child: Text('Discard', style: T.label.copyWith(fontSize: 13, color: C.brand))),
                            ),
                          ]),
                        ),
                ),
                PrimaryButton(label: 'Save Changes', busy: _saving, onTap: _dirty ? _save : null),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // Header card: photo, live name preview and how complete the profile is.
  Widget _photoHeader() {
    final sub = _draft;
    final (share, tip) = _completeness;
    final pct = (share * 100).round();
    final name = _name.text.trim().isEmpty ? 'Your name' : _name.text.trim();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: C.cardEdge)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 4, decoration: const BoxDecoration(gradient: G.brand)),
        Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Row(children: [
            Semantics(
              container: true,
              button: true,
              label: _photo == null ? 'Add a profile photo' : 'Change profile photo',
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: _changePhoto,
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Avatar(initials: sub.initials.isEmpty ? '?' : sub.initials, photo: _photo, size: 84),
                      // A small white badge with a black camera, clear against the orange photo circle.
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2)),
                          child: const Icon(Icons.photo_camera_sharp, size: 14, color: Colors.black),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: S.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: T.title.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text('Customer ID ${_orig.smsId}', style: T.caption.copyWith(fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: C.line),
        // Completeness: a flat bar and the next thing to add.
        Padding(
          padding: const EdgeInsets.fromLTRB(S.lg, S.md, S.lg, S.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Profile $pct% complete', style: T.label.copyWith(fontSize: 13))),
              if (pct == 100) Icon(Icons.check_sharp, size: 16, color: C.success),
            ]),
            const SizedBox(height: S.sm),
            Container(
              height: 4,
              color: C.line,
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: share,
                child: Container(decoration: BoxDecoration(color: pct == 100 ? C.success : null, gradient: pct == 100 ? null : G.brand)),
              ),
            ),
            if (tip != null) ...[
              const SizedBox(height: S.sm),
              Text(tip, style: T.caption.copyWith(fontSize: 12)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _statePicker() {
    final err = _tried ? _stateErr : null;
    final ok = _ok('state', _stateErr);
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
                  Icon(Icons.map_outlined, size: 20, color: err != null ? C.danger : C.muted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_state.isEmpty ? 'Choose your state' : _state, style: _state.isEmpty ? _Field.hintStyle : _Field.valueStyle)),
                  if (ok) ...[Icon(Icons.check_circle_sharp, size: 18, color: C.success), const SizedBox(width: 6)],
                  Icon(Icons.keyboard_arrow_down_sharp, color: C.muted),
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

/// Section heading with a short orange marker.
class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: S.xl, bottom: S.md),
        child: Row(children: [
          Container(width: 3, height: 14, decoration: const BoxDecoration(gradient: G.brand)),
          const SizedBox(width: S.sm),
          Semantics(header: true, child: Text(text, style: T.overline.copyWith(fontSize: 12, color: C.inkSoft))),
        ]),
      );
}

/// A labelled, outlined text field with an icon. The icon and border turn
/// orange when focused, red when there's a problem; a green tick shows once
/// a change is valid. Help or the problem shows underneath.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.error,
    this.ok = false,
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
  final IconData icon;
  final String? error;
  final bool ok;
  final String? help;
  final String? prefix;
  final bool optional;
  final TextInputType? keyboard;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;

  static TextStyle get labelStyle => T.caption.copyWith(fontSize: 12.5, color: C.inkSoft, fontWeight: FontWeight.w600);
  static TextStyle get valueStyle => T.body.copyWith(fontSize: 14, color: C.ink, fontWeight: FontWeight.w600);
  static TextStyle get hintStyle => T.body.copyWith(fontSize: 14, color: C.faint);
  static TextStyle get errorStyle => T.caption.copyWith(fontSize: 12, color: C.danger, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));
    final iconColor = WidgetStateColor.resolveWith((s) => error != null ? C.danger : (s.contains(WidgetState.focused) ? C.brand : C.muted));
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 20),
                if (prefix != null) ...[
                  const SizedBox(width: 10),
                  Text(prefix!, style: valueStyle.copyWith(color: C.inkSoft)),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: C.lineStrong),
                ],
              ]),
            ),
            prefixIconColor: iconColor,
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: ok ? Icon(Icons.check_circle_sharp, size: 18, color: C.success) : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
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
