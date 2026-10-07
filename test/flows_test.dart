// Smoke tests: walk every screen on mock data and fail on any layout
// overflow, across phone sizes, landscape and tablet, at normal, larger and
// very large text.

import 'package:dishtv_next/data/repository.dart';
import 'package:dishtv_next/main.dart';
import 'package:dishtv_next/ui/explore/channel_diff_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _screen(WidgetTester t, Size size, double text) async {
  t.view.devicePixelRatio = 3;
  t.view.physicalSize = size * 3;
  t.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  // Looping effects (spotlight, logo strips) rest when motion is reduced,
  // which also lets pumpAndSettle finish.
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Scrolls the screen's main list until [f] is built, then expects it.
Future<void> _see(WidgetTester t, Finder f) async {
  final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (var i = 0; i < 25 && f.evaluate().isEmpty; i++) {
    await t.drag(lists.last, const Offset(0, -250), warnIfMissed: false);
    await t.pumpAndSettle();
  }
  expect(f, findsWidgets);
}

/// Scrolls the main list up, then down, until [f] is built, then expects it.
Future<void> _find(WidgetTester t, Finder f) async {
  final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (final dy in const [250.0, -250.0]) {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await t.drag(lists.last, Offset(0, dy), warnIfMissed: false);
      await t.pumpAndSettle();
    }
  }
  expect(f, findsWidgets);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  // Lists build lazily: scroll the main list until the target exists.
  // Try downwards first, then back up (the target may be above the fold).
  final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (final dy in const [-250.0, 250.0]) {
    for (var i = 0; i < 25 && f.evaluate().isEmpty; i++) {
      await t.drag(lists.last, Offset(0, dy), warnIfMissed: false);
      await t.pumpAndSettle();
    }
  }
  final target = f.first;
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> _back(WidgetTester t) async {
  await t.tap(find.byTooltip('Back').last);
  await t.pumpAndSettle();
}

Future<void> _start(WidgetTester t) async {
  await t.pumpWidget(DishTvNext(repo: MockRepository(latency: Duration.zero)));
  await t.pumpAndSettle();
}

/// Tests render with a block placeholder font by default; load the real one
/// so layout checks match what people see.
Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Manrope-$w.ttf').readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);
  const sizes = {
    'small 320x568': Size(320, 568),
    'android 360x640': Size(360, 640),
    'phone 390x844': Size(390, 844),
    'large 412x915': Size(412, 915),
    'landscape 844x390': Size(844, 390),
    'tablet 800x1280': Size(800, 1280),
  };
  for (final s in sizes.entries) {
    for (final text in const [1.0, 1.3, 2.0]) {
      testWidgets('tour every screen — ${s.key}, text ×$text', (t) async {
        await _screen(t, s.value, text);
        await _start(t);

        // All services, every group.
        await _tap(t, find.textContaining('More in '));
        await _see(t, find.text('Channel No. Finder'));
        await _tap(t, find.text('My Pack'));
        expect(find.text('Your plan'), findsOneWidget);
        await _back(t);
        await _tap(t, find.text('Recharge & Offers'));
        await _see(t, find.text('Recharge for Friends & Family'));
        await _tap(t, find.text('Account & Support'));
        await _see(t, find.text('Request Technician'));
        await _back(t);

        // The side menu.
        await _find(t, find.byTooltip('Menu'));
        await _tap(t, find.byTooltip('Menu'));
        await _see(t, find.text('My account'));
        await _see(t, find.text('Regulatory Information'));
        final menuPack = find.descendant(of: find.byType(Drawer), matching: find.text('My Pack'));
        await _find(t, menuPack);
        await _tap(t, menuPack);
        expect(find.text('Your plan'), findsOneWidget);
        await _back(t);

        // Profile, from the side menu.
        await _find(t, find.byTooltip('Menu'));
        await _tap(t, find.byTooltip('Menu'));
        await _tap(t, find.text('My Profile'));
        expect(find.text('Profile'), findsOneWidget);
        await _see(t, find.text('Warranty'));
        await _see(t, find.textContaining('Installed'));
        await _tap(t, find.bySemanticsLabel(RegExp(r'^Living Room, VC ')));
        await _see(t, find.textContaining('Raise a warranty claim'));

        // Edit Profile: a bad pincode is caught, then the change saves.
        await _tap(t, find.text('Edit Profile'));
        expect(find.text('Add Photo'), findsNothing);
        await _tap(t, find.bySemanticsLabel('Add a profile photo'));
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Gallery'), findsOneWidget);
        expect(find.text('Files'), findsOneWidget);
        await t.tap(find.byTooltip('Close'));
        await t.pumpAndSettle();
        await _find(t, find.byKey(const ValueKey('field-name')));
        await t.enterText(find.descendant(of: find.byKey(const ValueKey('field-name')), matching: find.byType(TextField)), 'Kashyap R Raina');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await _find(t, find.byKey(const ValueKey('field-pincode')));
        await t.enterText(find.descendant(of: find.byKey(const ValueKey('field-pincode')), matching: find.byType(TextField)), '12');
        await t.pumpAndSettle();
        await _tap(t, find.text('Save Changes'));
        await _find(t, find.text('Enter a 6-digit pincode'));
        await t.enterText(find.descendant(of: find.byKey(const ValueKey('field-pincode')), matching: find.byType(TextField)), '201302');
        await t.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await _tap(t, find.bySemanticsLabel(RegExp(r'^State, ')));
        await _tap(t, find.text('Maharashtra'));
        await _tap(t, find.text('Save Changes'));
        await _find(t, find.text('Kashyap R Raina'));
        await _find(t, find.textContaining('Maharashtra 201302'));

        // Leaving with unsaved changes asks first. (Let the "Profile updated"
        // message clear first; it sits over the button for a few seconds.)
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        await _tap(t, find.text('Edit Profile'));
        await _find(t, find.byKey(const ValueKey('field-email')));
        await t.enterText(find.descendant(of: find.byKey(const ValueKey('field-email')), matching: find.byType(TextField)), 'kashyap@example.org');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await _find(t, find.text('1 unsaved change'));
        await _back(t);
        expect(find.text('Discard changes?'), findsOneWidget);
        await _tap(t, find.text('Keep editing'));
        expect(find.text('Edit Profile'), findsOneWidget);
        await _back(t);
        await _tap(t, find.text('Discard changes'));
        await _find(t, find.text('Contact details'));
        await _find(t, find.text('kashyap.raina@example.com'));
        await _back(t);

        // Change pack and the Switch TV sheet.
        await _tap(t, find.text('Change Pack'));
        await _tap(t, find.byTooltip('Switch TV'));
        expect(find.text('Which TV do you want to change?'), findsOneWidget);
        await t.tap(find.byTooltip('Close'));
        await t.pumpAndSettle();

        // Explore: OTT packs in SD, a pack's details and every channel-changes tab.
        await _tap(t, find.text('Explore packs'));
        await _tap(t, find.text('TV + OTT packs'));
        await _tap(t, find.text('SD'));
        await _tap(t, find.bySemanticsLabel(RegExp(r'^Details of ')));
        await _tap(t, find.bySemanticsLabel(RegExp(r'channels you keep, show list$')));
        await _tap(t, find.textContaining(RegExp(r'^You lose \d+$')));
        await _tap(t, find.textContaining(RegExp(r'^New \d+$')));
        await _back(t);
        await _back(t);
        await _back(t);

        // Add channels & services: all three tabs.
        await _tap(t, find.text('Add-ons'));
        expect(find.text('Add channels & services'), findsOneWidget);
        await _tap(t, find.text('Bouquets'));
        await _tap(t, find.text('Add-ons'));
        await _see(t, find.textContaining('Recording'));
        await _back(t);
        await _back(t);

        // Add / Remove: add a channel, filter, then the Remove groups.
        await _tap(t, find.text('Add/Remove Channel'));
        expect(find.text('Add / Remove'), findsOneWidget);
        await _see(t, find.text('Trending near you'));
        await _tap(t, find.bySemanticsLabel(RegExp(r'^Colors HD, ')));
        await _tap(t, find.byTooltip('Filters'));
        await _tap(t, find.text('Languages'));
        await _tap(t, find.text('Hindi'));
        await _tap(t, find.text('Broadcasters'));
        await _tap(t, find.text('Quality'));
        await _tap(t, find.text('Apply'));
        await _find(t, find.text('1 filter on'));
        await _tap(t, find.text('Remove'));
        await _tap(t, find.text('Single Channels'));
        await _find(t, find.byTooltip('Remove Star Sports 1 Hindi'));
        await _tap(t, find.text('OTT'));
        await _see(t, find.text('Zee5 Premium'));
        await _see(t, find.text('Review'));
        expect(t.takeException(), isNull);
      });

      testWidgets('explore → extras → review → success — ${s.key}, text ×$text', (t) async {
        await _screen(t, s.value, text);
        await _start(t);
        expect(find.text('Kashyap Raina'), findsOneWidget);

        await _tap(t, find.text('Change Pack'));
        await _see(t, find.text('CURRENT PACK'));
        await _see(t, find.text('Find my pack'));
        await _see(t, find.text('Add-ons'));

        await _tap(t, find.text('Explore packs'));
        expect(find.text('Choose a pack to continue'), findsOneWidget);
        await _tap(t, find.bySemanticsLabel(RegExp(r'^Compare Super Family Hindi')));
        await _tap(t, find.textContaining('Super Family Hindi'));
        expect(find.text('Continue'), findsOneWidget);

        await _tap(t, find.text('Compare').last);
        expect(find.text('Compare packs'), findsOneWidget);
        await _back(t);

        await _tap(t, find.bySemanticsLabel(RegExp(r'^Details of Super Family Hindi')));
        await _tap(t, find.bySemanticsLabel(RegExp(r'channels you lose, show list$')));
        expect(find.text('Channel changes'), findsOneWidget);
        await _see(t, find.byType(ChannelRow));
        await _tap(t, find.textContaining(RegExp(r'^New \d+$')));
        await t.pump(const Duration(milliseconds: 400));
        await _see(t, find.byType(ChannelRow));
        await _back(t);
        await _back(t);

        await _tap(t, find.text('Continue'));
        expect(find.text('Add channels & services'), findsOneWidget);
        await _tap(t, find.text('Animal Planet'));
        await _tap(t, find.text('Review'));
        await _see(t, find.text('YOUR NEW MONTHLY BILL'));

        await _tap(t, find.textContaining('Confirm & apply'));
        expect(find.text('Your plan is updated'), findsOneWidget);
        await _tap(t, find.text('Done'));
        expect(find.text('TV on the go'), findsOneWidget, reason: 'back on Home');
        expect(t.takeException(), isNull);
      });

      testWidgets('your plan, filters, AI — ${s.key}, text ×$text', (t) async {
        await _screen(t, s.value, text);
        await _start(t);
        await _tap(t, find.textContaining('More in '));
        await _see(t, find.text('Channel No. Finder'));
        await _back(t);

        await _tap(t, find.text('Change Pack'));
        await _tap(t, find.text('Your plan'));
        await _tap(t, find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Remove ')));
        expect(find.text('Review'), findsOneWidget);
        await _back(t);

        await _tap(t, find.text('Explore packs'));
        await _tap(t, find.text('Filters'));
        await _tap(t, find.text('Sports'));
        expect(find.textContaining(RegExp(r'^Show \d+ packs?$')), findsOneWidget);
        await _tap(t, find.textContaining(RegExp(r'^Show \d+ packs?$')));
        expect(find.text('Filters (1)'), findsOneWidget);
        await _back(t);

        await _tap(t, find.text('Find my pack'));
        await _tap(t, find.text('Hindi'));
        await _tap(t, find.text('Next'));
        await _tap(t, find.text('Sports'));
        await _tap(t, find.text('Movies'));
        await _tap(t, find.text('Next'));
        // A one-answer question moves on by itself.
        await _tap(t, find.text('TV and mobile'));
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(find.text('Which picture quality?'), findsOneWidget);
        await _tap(t, find.text('Next'));
        await _tap(t, find.text('Up to ₹500'));
        await _tap(t, find.text('Show my packs'));
        await _see(t, find.text('Best match'));

        // A pick opens its details; choosing goes to Review, then success.
        await _tap(t, find.text('Best match'));
        await _tap(t, find.textContaining('Choose this pack'));
        await _see(t, find.text('YOUR NEW MONTHLY BILL'));
        await _tap(t, find.textContaining('Confirm & apply'));
        expect(find.text('Your plan is updated'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('leaving a plan change asks first, and discarding clears it', (t) async {
    await _screen(t, const Size(390, 844), 1.0);
    await _start(t);
    await _tap(t, find.text('Add/Remove Channel'));
    await _see(t, find.text('Trending near you'));
    await _tap(t, find.bySemanticsLabel(RegExp(r'^Colors HD, ')));
    await _back(t);
    expect(find.text('Discard your changes?'), findsOneWidget);
    await _tap(t, find.text('Keep editing'));
    expect(find.text('Add / Remove'), findsOneWidget);
    await _back(t);
    await _tap(t, find.text('Discard changes'));
    expect(find.text('TV on the go'), findsOneWidget, reason: 'back on Home');

    // The discarded channel doesn't turn up in another flow.
    await _tap(t, find.text('OTT'));
    expect(find.text('Add OTT'), findsOneWidget);
    expect(find.text('Review'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('changing the number verifies both numbers, and a wrong OTP says so', (t) async {
    await _screen(t, const Size(390, 844), 1.0);
    await _start(t);
    await _tap(t, find.text('Account & Support'));
    await _tap(t, find.textContaining('More in '));
    await _tap(t, find.text('Update Mobile No.'));
    // The current number is verified first.
    await _tap(t, find.text('Change number'));
    expect(find.text('Verify your current number'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '123456');
    await t.pumpAndSettle();
    await _tap(t, find.text('Verify'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text('NEW MOBILE NUMBER'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '9123456789');
    await t.pumpAndSettle();
    await _tap(t, find.text('Send OTP'));
    await t.enterText(find.byType(TextField).last, '000000');
    await t.pumpAndSettle();
    await _tap(t, find.text('Verify & Update'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.textContaining("That OTP isn't right"), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a bundle replaces an app you already pay for', (t) async {
    await _screen(t, const Size(390, 844), 1.0);
    await _start(t);
    // My TV has ZEE5 Premium; the Entertainment Bundle includes ZEE5.
    await _tap(t, find.text('OTT'));
    await _tap(t, find.bySemanticsLabel(RegExp(r'^Add Entertainment Bundle')));
    await _tap(t, find.text('Review'));
    await _see(t, find.text('YOUR NEW MONTHLY BILL'));
    await _see(t, find.textContaining(RegExp('removing', caseSensitive: false)));
    await _see(t, find.text('Zee5 Premium'));
    expect(t.takeException(), isNull);
  });
}
