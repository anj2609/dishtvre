// Choose Language: the languages in their own script on one quiet panel,
// with the English name in grey. The chosen one gets an orange check. The
// choice is kept for the session.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/widgets.dart';

const _langs = [
  ('English', 'English'),
  ('हिन्दी', 'Hindi'),
  ('ગુજરાતી', 'Gujarati'),
  ('தமிழ்', 'Tamil'),
  ('తెలుగు', 'Telugu'),
  ('ಕನ್ನಡ', 'Kannada'),
  ('മലയാളം', 'Malayalam'),
  ('বাংলা', 'Bengali'),
  ('मराठी', 'Marathi'),
];

/// The chosen language (English name), kept while the app is open.
final appLanguage = ValueNotifier<String>('English');

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Widget _row(BuildContext context, String native, String english, bool on) => Semantics(
        button: true,
        selected: on,
        label: english == native ? english : '$native, $english',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () {
              appLanguage.value = english;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                // The app is in English for now; say so rather than claim a switch.
                ..showSnackBar(SnackBar(
                    content: Text(english == 'English' ? 'The app is in English' : '$english saved. The app switches to it when translations arrive.')));
            },
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.lg),
                child: Row(children: [
                  Expanded(child: Text(native, style: T.item.copyWith(fontSize: 16, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? C.ink : C.inkSoft))),
                  if (english != native) Text(english, style: T.caption.copyWith(fontSize: 12.5, color: C.muted)),
                  const SizedBox(width: S.md),
                  SizedBox(width: 22, child: on ? BrandShade(child: Icon(Icons.check_sharp, color: C.brand, size: 21)) : null),
                ]),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Header(title: 'Choose Language'),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: appLanguage,
              // One quiet panel; the chosen language gets an orange check.
              builder: (context, current, _) => ListView(
                padding: EdgeInsets.fromLTRB(S.page, S.md, S.page, S.lg + MediaQuery.paddingOf(context).bottom),
                children: [
                  Container(
                    color: C.surface,
                    child: Column(children: [
                      for (final (i, l) in _langs.indexed) ...[
                        if (i > 0) Divider(height: 1, thickness: 1, color: C.line, indent: S.lg, endIndent: S.lg),
                        _row(context, l.$1, l.$2, l.$2 == current),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
