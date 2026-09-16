import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/bookings/booking_data.dart';
import 'package:arena_mobile/shared/paged_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fakes.dart';

void main() {
  test(
    'admin scope, server filters, page size and successful refresh replacement',
    () async {
      final adapter = BookingAdapter((request) {
        final page = request.queryParameters['page'] as int;
        return BookingAdapter.json(
          pageJson([bookingJson('$page')], page: page, totalPages: 2),
        );
      });
      final api = ArenaApi(basePathOverride: 'https://example.test');
      api.dio.httpClientAdapter = adapter;
      final provider =
          NotifierProvider.autoDispose<
            BookingsController,
            PagedListState<BookingResponse>
          >(BookingsController.new);
      final container = ProviderContainer(
        overrides: [arenaApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      expect(adapter.requests, isEmpty);
      await controller.filter(eventId: 'chosen', status: 'CONFIRMED');
      await controller.loadMore();
      expect(container.read(provider).items.map((e) => e.id), ['0', '1']);
      for (final request in adapter.requests) {
        expect(request.queryParameters, containsPair('scope', 'all'));
        expect(request.queryParameters, containsPair('eventId', 'chosen'));
        expect(request.queryParameters, containsPair('status', 'CONFIRMED'));
        expect(request.queryParameters, containsPair('size', 20));
      }
      await controller.refresh();
      expect(container.read(provider).items.map((e) => e.id), ['0']);
      await controller.filter();
      expect(adapter.requests.last.queryParameters['eventId'], isNull);
      expect(adapter.requests.last.queryParameters['status'], isNull);
    },
  );

  test(
    'refresh failure retains accumulated bookings and retry replaces them',
    () async {
      var fail = false;
      final adapter = BookingAdapter(
        (request) => fail
            ? BookingAdapter.json({'detail': 'failure'}, status: 500)
            : BookingAdapter.json(
                pageJson(
                  [bookingJson('${request.queryParameters['page']}')],
                  page: request.queryParameters['page'] as int,
                  totalPages: 2,
                ),
              ),
      );
      final api = ArenaApi(basePathOverride: 'https://example.test');
      api.dio.httpClientAdapter = adapter;
      final provider =
          NotifierProvider.autoDispose<
            BookingsController,
            PagedListState<BookingResponse>
          >(BookingsController.new);
      final container = ProviderContainer(
        overrides: [arenaApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      await controller.refresh();
      await controller.loadMore();
      fail = true;
      await controller.refresh();
      expect(container.read(provider).items, hasLength(2));
      expect(container.read(provider).error, contains('server'));
      fail = false;
      await controller.retry();
      expect(container.read(provider).items, hasLength(1));
    },
  );

  test('cancellation eligibility includes cancelled events but excludes history and started events', () {
    expect(canCancelBooking(bookingFixture(), bookingNow), isTrue);
    expect(
      canCancelBooking(bookingFixture(eventStatus: 'CANCELLED'), bookingNow),
      isTrue,
    );
    for (final status in ['LIVE', 'COMPLETED']) {
      expect(
        canCancelBooking(bookingFixture(eventStatus: status), bookingNow),
        isFalse,
      );
    }
    expect(
      canCancelBooking(bookingFixture(status: 'CANCELLED'), bookingNow),
      isFalse,
    );
    expect(
      canCancelBooking(
        bookingFixture(),
        bookingNow.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });
}
