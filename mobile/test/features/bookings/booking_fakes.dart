import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';

final bookingNow = DateTime.utc(2030, 1, 1, 12);

Map<String, Object?> eventJson(String id, {String status = 'SCHEDULED'}) => {
  'id': id,
  'title': 'Event $id',
  'sport': 'Tennis',
  'location': 'Court 1',
  'startsAt': bookingNow.add(const Duration(hours: 1)).toIso8601String(),
  'endsAt': bookingNow.add(const Duration(hours: 2)).toIso8601String(),
  'capacity': 20,
  'status': status,
  'createdAt': bookingNow.toIso8601String(),
  'updatedAt': bookingNow.toIso8601String(),
};

Map<String, Object?> bookingJson(
  String id, {
  String status = 'CONFIRMED',
  String eventStatus = 'SCHEDULED',
}) => {
  'id': id,
  'event': eventJson('event-$id', status: eventStatus),
  'status': status,
  'participant': {'id': 'participant-$id', 'displayName': 'Player $id'},
  'createdAt': bookingNow.toIso8601String(),
  'updatedAt': bookingNow.toIso8601String(),
};

Map<String, Object?> pageJson(
  List<Map<String, Object?>> items, {
  int page = 0,
  int totalPages = 1,
}) => {
  'items': items,
  'page': page,
  'size': 20,
  'totalElements': totalPages > 1 ? 21 : items.length,
  'totalPages': totalPages,
};

BookingResponse bookingFixture({
  String status = 'CONFIRMED',
  String eventStatus = 'SCHEDULED',
}) => standardSerializers.deserializeWith(
  BookingResponse.serializer,
  bookingJson('1', status: status, eventStatus: eventStatus),
)!;

class BookingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  FutureOr<ResponseBody> Function(RequestOptions) handle;
  BookingAdapter(this.handle);

  static ResponseBody json(Object body, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}
