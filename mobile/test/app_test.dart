import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arena_mobile/app.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Finder destination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('starts on Events and switches between feature placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(const ArenaApp());

    expect(appBarTitle('Events'), findsOneWidget);
    expect(find.text('Events unavailable'), findsOneWidget);
    expect(find.text('Event loading is not connected yet.'), findsOneWidget);
    expect(find.text('Bookings unavailable'), findsNothing);

    await tester.tap(destination('Bookings'));
    await tester.pumpAndSettle();

    expect(appBarTitle('Bookings'), findsOneWidget);
    expect(find.text('Bookings unavailable'), findsOneWidget);
    expect(find.text('Booking loading is not connected yet.'), findsOneWidget);
    expect(find.text('Events unavailable'), findsNothing);

    await tester.tap(destination('Events'));
    await tester.pumpAndSettle();

    expect(appBarTitle('Events'), findsOneWidget);
    expect(find.text('Events unavailable'), findsOneWidget);
    expect(find.text('Bookings unavailable'), findsNothing);
  });

  testWidgets('Account explains sign-in state and closes on the current tab', (
    tester,
  ) async {
    await tester.pumpWidget(const ArenaApp());
    await tester.tap(destination('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is not configured yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is not configured yet.'), findsNothing);
    expect(appBarTitle('Bookings'), findsOneWidget);
    expect(find.text('Bookings unavailable'), findsOneWidget);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('fits a 375px screen at ${textScale}x text scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ArenaApp());
      await tester.pumpAndSettle();
      expect(find.text('Events unavailable').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(destination('Bookings'));
      await tester.pumpAndSettle();
      expect(find.text('Bookings unavailable').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sign-in is not configured yet.').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
