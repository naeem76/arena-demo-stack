import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/app.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/event_drafts.dart';
import 'package:arena_mobile/features/bookings/booking_data.dart';
import 'package:arena_mobile/features/bookings/booking_event_picker.dart';
import 'package:arena_mobile/shared/local_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_fakes.dart';
import 'app_test.dart' show destination;
import 'auth_fakes.dart';
import 'features/bookings/booking_fakes.dart';

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  Finder? surface,
}) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find
        .descendant(
          of: surface ?? find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  for (final viewport in [(384.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'audited surfaces usable at ${viewport.$1}px / ${viewport.$2}x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(viewport.$1, 832);
        tester.platformDispatcher.textScaleFactorTestValue = viewport.$2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const title = 'Community football evening with local players';
        final event = eventJson('event-1')
          ..['title'] = title
          ..['location'] = 'Riverside Sports Centre · Court 2'
          ..['description'] = '';
        final booking = bookingJson('1')..['event'] = event;
        final adapter = BookingAdapter(
          (request) => BookingAdapter.json(switch (request.uri.path) {
            '/api/events' => pageJson([event]),
            '/api/bookings' => pageJson([booking]),
            '/api/events/event-1' => event,
            _ => booking,
          }),
        );
        final api = ArenaApi(basePathOverride: testOrigin);
        api.dio.httpClientAdapter = adapter;
        addTearDown(() => api.dio.close(force: true));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              configuredApiUrlProvider.overrideWithValue(testOrigin),
              authProvider.overrideWith(SignedInController.new),
              arenaApiProvider.overrideWithValue(api),
              bookingClockProvider.overrideWithValue(() => bookingNow),
              eventDraftStoreProvider.overrideWithValue(
                MemoryEventDraftStore(),
              ),
            ],
            child: const ArenaApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final create = find.widgetWithText(FilledButton, 'Create');
        expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
        await tester.tap(create);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a whole number of at least 1'), findsOneWidget);
        expect(find.text('Choose a start date and time'), findsOneWidget);
        expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await reveal(tester, find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('Event details'), findsOneWidget);
        if (viewport.$2 == 1) {
          expect(find.text('Edit').hitTestable(), findsOneWidget);
          expect(find.text('View bookings').hitTestable(), findsOneWidget);
        } else {
          await reveal(tester, find.text('Edit'));
          await reveal(tester, find.text('View bookings'));
        }
        await reveal(tester, find.text('No description provided.'));
        await reveal(tester, find.text('Delete event'));
        final delete = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Delete event'),
        );
        final colors = Theme.of(tester.element(find.text('Delete event')))
            .colorScheme;
        expect(delete.style!.foregroundColor!.resolve({}), colors.error);
        await reveal(tester, find.widgetWithText(SelectableText, 'event-1'));
        expect(find.widgetWithText(SelectableText, 'event-1'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(destination('Bookings'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMED').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('All events'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final picker = find.byType(BookingEventPicker);
        final choice = find.descendant(of: picker, matching: find.text(title));
        await reveal(tester, choice, surface: picker);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await reveal(tester, find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Cancel booking'));
        await tester.tap(find.text('Cancel booking'));
        await tester.pumpAndSettle();
        expect(find.text('Keep booking'), findsOneWidget);
        final confirmation = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Cancel booking'),
        );
        expect(
          tester
              .widget<FilledButton>(confirmation)
              .style!
              .backgroundColor!
              .resolve({}),
          colors.error,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Keep booking'));
        await tester.pumpAndSettle();
        expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SelectableText, testOrigin), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(find.text('Arena Admin'), findsOneWidget);
        final titleWidget = tester.widget<Text>(find.text('Arena Admin'));
        expect(titleWidget.style!.color, colors.onSurface);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'shared local date includes year and respects 24 hour preference',
    (tester) async {
      late String formatted;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: Builder(
              builder: (context) {
                formatted = localTime(
                  context,
                  DateTime(2030, 9, 24, 18, 5, 12, 345, 678),
                );
                return Text(formatted);
              },
            ),
          ),
        ),
      );
      expect(formatted, contains('2030'));
      expect(formatted, contains('18:05'));
      expect(formatted, isNot(contains('345678')));
    },
  );
}
