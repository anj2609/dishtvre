// The photo editor frames an image and hands back a square PNG.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dishtv_next/app/theme.dart';
import 'package:dishtv_next/ui/home/photo_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rotate, reset and use a photo', (t) async {
    final src = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGN4ESyFFTEMLQkAgzdVQShZHb8AAAAASUVORK5CYII=');
    Uint8List? result;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => PhotoEditorScreen(bytes: src))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Edit photo'), findsOneWidget);
    await t.tap(find.text('Rotate'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset'));
    await t.pumpAndSettle();
    await t.tap(find.text('Flip'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Mono effect'));
    await t.pumpAndSettle();
    expect(find.text('Noir'), findsOneWidget);

    // Rendering to an image needs real async work.
    await t.runAsync(() async {
      await t.tap(find.text('Use photo'));
      for (var i = 0; i < 50 && result == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await t.pump();
      }
    });
    await t.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.sublist(1, 4), utf8.encode('PNG'));
    expect(find.text('Edit photo'), findsNothing);
  });
}
