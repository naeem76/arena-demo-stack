import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/bookings/booking_data.dart';
import 'package:arena_mobile/features/bookings/bookings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_fakes.dart';
import 'booking_fakes.dart';

void main() {
  testWidgets(
    'system back waits for cancellation and then refreshes the existing list',
    (tester) async {
      final cancellation = Completer<ResponseBody>();
      var cancelled = false;
      var listReads = 0;
      final adapter = BookingAdapter((request) {
        if (request.method != 'GET') {
          cancelled = true;
          return cancellation.future;
        }
        final record = bookingJson(
          '1',
          status: cancelled ? 'CANCELLED' : 'CONFIRMED',
        );
        if (request.uri.path.endsWith('/bookings')) {
          listReads++;
          return BookingAdapter.json(pageJson([record]));
        }
        return BookingAdapter.json(record);
      });
      final api = ArenaApi(basePathOverride: testOrigin);
      api.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arenaApiProvider.overrideWithValue(api),
            apiBaseUrlProvider.overrideWithValue(testOrigin),
            authProvider.overrideWith(SignedInController.new),
            bookingClockProvider.overrideWithValue(() => bookingNow),
          ],
          child: const MaterialApp(home: Scaffold(body: BookingsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event event-1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel booking'));
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel booking'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        adapter.requests.where((request) => request.method != 'GET'),
        hasLength(1),
      );
      expect(listReads, 1);
      expect(find.text('Cancelling…'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Booking details'), findsOneWidget);
      expect(find.text('Cancelling…'), findsOneWidget);
      expect(find.text('All participant bookings'), findsNothing);
      expect(listReads, 1);
      cancellation.complete(
        BookingAdapter.json(bookingJson('1', status: 'CANCELLED')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Current status: CANCELLED'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(listReads, 2);
      expect(find.text('All participant bookings'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget); // Filter chip only.
      expect(
        find.text('CANCELLED'),
        findsNWidgets(2),
      ); // Chip and updated card.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('incoming event filter applies only when revision changes', (
    tester,
  ) async {
    final adapter = BookingAdapter(
      (request) => BookingAdapter.json(
        request.uri.path == '/api/events/chosen'
            ? (eventJson('chosen')..['title'] = 'Chosen event')
            : pageJson([]),
      ),
    );
    Map<String, dynamic> bookingQuery() => adapter.requests
        .lastWhere((request) => request.uri.path == '/api/bookings')
        .queryParameters;
    final api = ArenaApi(basePathOverride: testOrigin);
    api.dio.httpClientAdapter = adapter;
    var revision = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arenaApiProvider.overrideWithValue(api),
          apiBaseUrlProvider.overrideWithValue(testOrigin),
          authProvider.overrideWith(SignedInController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return BookingsScreen(
                  eventId: 'chosen',
                  eventTitle: 'Chosen event',
                  filterRevision: revision,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(bookingQuery()['eventId'], 'chosen');
    await tester.tap(find.text('CANCELLED'));
    await tester.pumpAndSettle();
    expect(bookingQuery()['status'], 'CANCELLED');
    expect(bookingQuery()['scope'], 'all');
    await tester.tap(find.text('Clear event filter'));
    await tester.pumpAndSettle();
    expect(bookingQuery()['eventId'], isNull);
    final count = adapter.requests.length;
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(count));
    expect(find.text('All events'), findsOneWidget);
    expect(bookingQuery()['status'], 'CANCELLED');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'CANCELLED'))
          .selected,
      isTrue,
    );
    rebuild(() => revision++);
    await tester.pumpAndSettle();
    expect(bookingQuery()['eventId'], 'chosen');
    expect(bookingQuery()['status'], isNull);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All statuses'))
          .selected,
      isTrue,
    );
    expect(find.text('Event: Chosen event'), findsOneWidget);
  });
}
