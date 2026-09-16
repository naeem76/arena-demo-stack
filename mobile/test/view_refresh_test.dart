import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/app.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/events/event_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';
import 'features/bookings/booking_fakes.dart';

Finder tab(String name) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(name));

void main() {
  testWidgets(
    'each tab opening fetches fresh data without stale or empty-state flashes',
    (tester) async {
      Completer<ResponseBody>? eventGate, bookingGate;
      var eventReads = 0, bookingReads = 0;
      final adapter = BookingAdapter((request) {
        if (request.uri.path == '/api/events') {
          eventReads++;
          return eventGate?.future ??
              BookingAdapter.json(pageJson([eventJson('one')]));
        }
        expect(request.uri.path, '/api/bookings');
        bookingReads++;
        return bookingGate?.future ??
            BookingAdapter.json(pageJson([bookingJson('one')]));
      });
      final api = ArenaApi()..dio.httpClientAdapter = adapter;
      addTearDown(() => api.dio.close(force: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configuredApiUrlProvider.overrideWithValue(testOrigin),
            authProvider.overrideWith(SignedInController.new),
            arenaApiProvider.overrideWithValue(api),
          ],
          child: const ArenaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(eventReads, 1);
      expect(bookingReads, 0);
      expect(find.text('Event one'), findsOneWidget);

      await tester.tap(tab('Bookings'));
      await tester.pumpAndSettle();
      expect(bookingReads, 1);
      expect(find.text('Event event-one'), findsOneWidget);

      eventGate = Completer<ResponseBody>();
      await tester.tap(tab('Events'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(eventReads, 2);
      expect(find.text('Event one'), findsNothing);
      expect(find.text('No events found.'), findsNothing);
      expect(find.text('0 of 0 items'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      eventGate.complete(BookingAdapter.json(pageJson([], totalPages: 0)));
      await tester.pumpAndSettle();
      expect(find.text('No events found.'), findsOneWidget);
      expect(find.text('0 of 0 items'), findsOneWidget);

      bookingGate = Completer<ResponseBody>();
      await tester.tap(tab('Bookings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(bookingReads, 2);
      expect(find.text('Event event-one'), findsNothing);
      expect(find.text('No bookings match these filters.'), findsNothing);
      expect(find.text('0 of 0 items'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      bookingGate.complete(BookingAdapter.json(pageJson([], totalPages: 0)));
      await tester.pumpAndSettle();
      expect(find.text('No bookings match these filters.'), findsOneWidget);
      expect(find.text('0 of 0 items'), findsOneWidget);
    },
  );

  testWidgets(
    'event details wait for the server instead of rendering the list snapshot',
    (tester) async {
      final gate = Completer<ResponseBody>();
      final api = ArenaApi()
        ..dio.httpClientAdapter = BookingAdapter((_) => gate.future);
      addTearDown(() => api.dio.close(force: true));
      final snapshot = standardSerializers.deserializeWith(
        EventResponse.serializer,
        eventJson('one')..['title'] = 'Stale snapshot',
      )!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(SignedInController.new),
            arenaApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(home: EventDetailScreen(event: snapshot)),
        ),
      );
      await tester.pump();
      expect(find.text('Stale snapshot'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(
        BookingAdapter.json(eventJson('one')..['title'] = 'Fresh title'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stale snapshot'), findsNothing);
      expect(find.text('Fresh title'), findsOneWidget);
    },
  );
}
