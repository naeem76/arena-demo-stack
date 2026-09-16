import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../shared/paged_list.dart';

final bookingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

bool canCancelBooking(BookingResponse booking, DateTime now) =>
    booking.status.name == 'CONFIRMED' &&
    now.isBefore(booking.event.startsAt) &&
    !const ['LIVE', 'COMPLETED'].contains(booking.event.status.name);

class BookingsController extends PagedListController<BookingResponse> {
  BookingsController({this.eventId});

  String? eventId;
  String? status;

  Future<void> filter({String? eventId, String? status}) {
    this.eventId = eventId;
    this.status = status;
    return refresh(reset: true);
  }

  @override
  String itemId(BookingResponse item) => item.id;

  @override
  Future<PageResult<BookingResponse>> fetchPage(
    int page,
    int size,
    CancelToken cancelToken,
  ) async {
    final result =
        (await ref
                .read(arenaApiProvider)
                .getBookingsApi()
                .list1(
                  scope: 'all',
                  eventId: eventId,
                  status: status,
                  page: page,
                  size: size,
                  cancelToken: cancelToken,
                ))
            .data!;
    return PageResult(
      items: result.items.toList(),
      page: result.page,
      size: result.size,
      totalElements: result.totalElements,
      totalPages: result.totalPages,
    );
  }
}

class BookingEventsController extends PagedListController<EventResponse> {
  @override
  String itemId(EventResponse item) => item.id;

  @override
  Future<PageResult<EventResponse>> fetchPage(
    int page,
    int size,
    CancelToken cancelToken,
  ) async {
    final result =
        (await ref
                .read(arenaApiProvider)
                .getEventsApi()
                .list(page: page, size: size, cancelToken: cancelToken))
            .data!;
    return PageResult(
      items: result.items.toList(),
      page: result.page,
      size: result.size,
      totalElements: result.totalElements,
      totalPages: result.totalPages,
    );
  }
}
