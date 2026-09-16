import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/bookings/booking_event_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth_fakes.dart';
import 'booking_fakes.dart';

void main() {
  testWidgets(
    'picker keeps off-page selection and explicitly loads bounded pages at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final adapter = BookingAdapter((request) {
        final page = request.queryParameters['page'] as int;
        return BookingAdapter.json(
          pageJson([eventJson('page-$page')], page: page, totalPages: 2),
        );
      });
      final api = ArenaApi(basePathOverride: 'https://example.test');
      api.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arenaApiProvider.overrideWithValue(api),
            apiBaseUrlProvider.overrideWithValue(testOrigin),
            authProvider.overrideWith(SignedInController.new),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: BookingEventPicker(
                selectedId: 'elsewhere',
                selectedTitle: 'Off-page event',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.queryParameters['size'], 20);
      expect(find.text('Selected: Off-page event'), findsOneWidget);
      expect(find.text('All events'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.queryParameters['page'], 1);
      expect(find.text('Selected: Off-page event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
