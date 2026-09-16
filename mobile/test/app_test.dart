import 'package:arena_mobile/app.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/event_drafts.dart';
import 'package:arena_mobile/features/bookings/bookings_screen.dart';
import 'package:arena_mobile/features/events/events_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_fakes.dart';
import 'auth_fakes.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));
Finder destination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> pumpApp(WidgetTester tester) async {
  final api = emptyAppApi();
  addTearDown(() => api.dio.close(force: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configuredApiUrlProvider.overrideWithValue('http://localhost:8080'),
        authProvider.overrideWith(
          () => SignedInController(origin: 'http://localhost:8080'),
        ),
        arenaApiProvider.overrideWithValue(api),
        eventDraftStoreProvider.overrideWithValue(MemoryEventDraftStore()),
      ],
      child: const ArenaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'switches retained feature tabs with the icon beside each title',
    (tester) async {
      await pumpApp(tester);
      expect(appBarTitle('Events'), findsOneWidget);
      final events = tester.element(find.byType(EventsScreen));
      final icon = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.event_outlined),
      );
      expect(
        tester.getCenter(icon).dy,
        closeTo(tester.getCenter(appBarTitle('Events')).dy, 1),
      );
      expect(
        tester.getRect(icon).right,
        lessThan(tester.getRect(appBarTitle('Events')).left),
      );

      await tester.tap(destination('Bookings'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Bookings'), findsOneWidget);
      expect(find.byType(BookingsScreen), findsOneWidget);
      await tester.tap(destination('Events'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(EventsScreen)), same(events));
    },
  );

  testWidgets('Account closes back to the selected tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(destination('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Arena Administrator'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.text('Arena Administrator'), findsNothing);
    expect(appBarTitle('Bookings'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits a 375px screen at ${scale}x text scale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester);
      expect(appBarTitle('Events').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(destination('Bookings'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Bookings').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Arena Administrator').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
