import 'dart:async';

import 'package:arena_mobile/core/api/api_boundary.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/bookings/booking_data.dart';
import 'package:arena_mobile/features/bookings/booking_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_fakes.dart';
import 'booking_fakes.dart';

Future<ProviderContainer> mountDetail(
  WidgetTester tester,
  BookingAdapter adapter, {
  DateTime Function()? clock,
}) async {
  late ProviderContainer container;
  final api = createArenaApi(
    apiBaseUrl: testOrigin,
    accessToken: () =>
        container.read(authProvider.notifier).tokenFor(testOrigin),
    onUnauthorized: (token) =>
        container.read(authProvider.notifier).invalidate(token: token),
  );
  api.dio.httpClientAdapter = adapter;
  container = ProviderContainer(
    overrides: [
      arenaApiProvider.overrideWithValue(api),
      apiBaseUrlProvider.overrideWithValue(testOrigin),
      authProvider.overrideWith(SignedInController.new),
      bookingClockProvider.overrideWithValue(clock ?? () => bookingNow),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BookingDetailScreen(bookingId: '1')),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> openConfirmation(WidgetTester tester) async {
  if (find.text('Cancel booking').evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text('Cancel booking'), 200);
  }
  await tester.ensureVisible(find.text('Cancel booking'));
  await tester.tap(find.text('Cancel booking'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel booking'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('disposing during cancellation ignores its late response', (
    tester,
  ) async {
    final gate = Completer<ResponseBody>();
    final adapter = BookingAdapter(
      (request) => request.method == 'GET'
          ? BookingAdapter.json(bookingJson('1'))
          : gate.future,
    );
    await mountDetail(tester, adapter);
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    gate.complete(BookingAdapter.json(bookingJson('1', status: 'CANCELLED')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'decline sends no mutation; pending cancellation prevents duplicates and retains history',
    (tester) async {
      final gate = Completer<ResponseBody>();
      final adapter = BookingAdapter(
        (request) => request.method == 'GET'
            ? BookingAdapter.json(bookingJson('1'))
            : gate.future,
      );
      await mountDetail(tester, adapter);
      await openConfirmation(tester);
      expect(find.text('Cancelling…'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancel booking'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Keep booking', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.method != 'GET'), isEmpty);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(adapter.requests.where((r) => r.method != 'GET'), hasLength(1));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancelling…'),
            )
            .onPressed,
        isNull,
      );
      gate.complete(BookingAdapter.json(bookingJson('1', status: 'CANCELLED')));
      await tester.pumpAndSettle();
      expect(find.text('Cancel booking'), findsNothing);
      expect(
        find.text('This booking was cancelled. Its history is retained.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('time and auth are rechecked after confirmation', (tester) async {
    var now = bookingNow;
    final adapter = BookingAdapter(
      (request) => BookingAdapter.json(bookingJson('1')),
    );
    final container = await mountDetail(tester, adapter, clock: () => now);
    await openConfirmation(tester);
    now = bookingNow.add(const Duration(hours: 1));
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(
      find.text('This booking can no longer be cancelled.'),
      findsOneWidget,
    );
    now = bookingNow;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    container.read(authProvider.notifier).invalidate();
    await tester.pump();
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(find.text('Sign in again to cancel this booking.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('409 reloads detail and keeps conflict error beside history', (
    tester,
  ) async {
    var reads = 0;
    final adapter = BookingAdapter((request) {
      if (request.method == 'GET') {
        return BookingAdapter.json(
          bookingJson('1', status: ++reads == 1 ? 'CONFIRMED' : 'CANCELLED'),
        );
      }
      return BookingAdapter.json({
        'detail': 'Booking changed. Review current status.',
      }, status: 409);
    });
    await mountDetail(tester, adapter);
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Booking changed. Review current status.'), findsWidgets);
    expect(find.text('Current status: CANCELLED'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    '401 invalidates auth and disables further mutations without inline sign-in',
    (tester) async {
      final adapter = BookingAdapter(
        (request) => request.method == 'GET'
            ? BookingAdapter.json(bookingJson('1'))
            : BookingAdapter.json({'detail': 'expired'}, status: 401),
      );
      final container = await mountDetail(tester, adapter);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(container.read(authProvider).session, isNull);
      expect(container.read(authProvider).hasSignedIn, isTrue);
      expect(find.text('Sign in again'), findsNothing);
      expect(
        find.text('Your session has expired. Sign in again to continue.'),
        findsWidgets,
      );
      await tester.ensureVisible(find.text('Cancel booking'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancel booking'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'other failures retain original record and offer confirmed retry',
    (tester) async {
      final adapter = BookingAdapter(
        (request) => request.method == 'GET'
            ? BookingAdapter.json(bookingJson('1'))
            : BookingAdapter.json({'detail': 'unavailable'}, status: 500),
      );
      await mountDetail(tester, adapter);
      await openConfirmation(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.text('Current status: CONFIRMED'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(adapter.requests.where((r) => r.method != 'GET'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
