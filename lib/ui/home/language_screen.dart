// Choose Language: eight languages, each with a solid colour block showing
// its first letter. The chosen one fills with its colour. The choice is kept
// for the session.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/widgets.dart';

const _langs = [
  ('English', 'English', Color(0xFFD9552B)),
  ('हिन्दी', 'Hindi', Color(0xFF6656E0)),
  ('ગુજરાતી', 'Gujarati', Color(0xFF0E9488)),
  ('தமிழ்', 'Tamil', Color(0xFF2F5FC4)),
  ('తెలుగు', 'Telugu', Color(0xFFC2384A)),
  ('ಕನ್ನಡ', 'Kannada', Color(0xFF1F7A55)),
  ('മലയാളം', 'Malayalam', Color(0xFFB7791F)),
  ('বাংলা', 'Bengali', Color(0xFF8B3FC4)),
  ('मराठी', 'Marathi', Color(0xFF3B7FA8)),
];

/// The chosen language (English name), kept while the app is open.
final appLanguage = ValueNotifier<String>('English');

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

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
              builder: (context, current, _) => ListView.separated(
                padding: EdgeInsets.fromLTRB(S.page, S.sm, S.page, S.lg + MediaQuery.paddingOf(context).bottom),
                itemCount: _langs.length,
                separatorBuilder: (_, __) => const SizedBox(height: S.sm + 2),
                itemBuilder: (_, i) {
                  final (native, english, color) = _langs[i];
                  final on = english == current;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: english == native ? english : '$native, $english',
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () {
                          appLanguage.value = english;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text('Language set to $english')));
                        },
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: on ? C.brand : C.surface,
                            border: Border(
                              left: BorderSide(color: on ? C.brand : color, width: 5),
                              top: BorderSide(color: on ? C.brand : C.cardEdge),
                              right: BorderSide(color: on ? C.brand : C.cardEdge),
                              bottom: BorderSide(color: on ? C.brand : C.cardEdge),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: S.lg),
                          child: Row(children: [
                            Expanded(child: Text(native, style: T.title.copyWith(fontSize: 19, color: on ? C.onInk : C.ink))),
                            if (english != native) Text(english, style: T.body.copyWith(fontSize: 14, color: on ? C.onInk : C.muted)),
                            if (on) ...[const SizedBox(width: S.md), const Icon(Icons.check_sharp, color: C.onInk, size: 22)],
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
