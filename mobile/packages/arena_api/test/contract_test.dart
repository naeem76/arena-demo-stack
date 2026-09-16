import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arena_api/arena_api.dart';
import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const id = '550e8400-e29b-41d4-a716-446655440000';
const timestamp = '2026-10-01T10:00:00Z';
Map<String, dynamic> event() => {
      'id': id,
      'title': 'Tennis final',
      'sport': 'Tennis',
      'location': 'Court 1',
      'startsAt': timestamp,
      'endsAt': '2026-10-01T12:00:00Z',
      'capacity': 20,
      'status': 'SCHEDULED',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    };
Map<String, dynamic> booking() => {
      'id': id,
      'event': event(),
      'status': 'CONFIRMED',
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'participant': {'id': id, 'displayName': 'Contract participant'},
    };
Map<String, dynamic> page(Map<String, dynamic> item) => {
      'items': [item],
      'page': 0,
      'size': 20,
      'totalElements': 1,
      'totalPages': 1,
    };
Map<String, dynamic> problem(int status) => {
      'type': 'about:blank',
      'title': 'Contract error',
      'status': status,
      'detail': 'Fixture error',
      'instance': '/api/events/$id',
      'properties': {'traceId': 'contract-1'},
    };
T decode<T>(Object json) =>
    standardSerializers.deserialize(json, specifiedType: FullType(T)) as T;
Map<String, dynamic> encode<T>(T value) => Map<String, dynamic>.from(
    standardSerializers.serialize(value, specifiedType: FullType(T)) as Map);

class Stub implements HttpClientAdapter {
  int status = 200;
  Object? body;
  String contentType = 'application/json';
  late RequestOptions request;
  String? sentBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    sentBody = requestStream == null
        ? null
        : utf8.decode(await requestStream
            .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk)));
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status,
        headers: {
          Headers.contentTypeHeader: [contentType],
          'location': ['/api/events/$id'],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // Docker mounts the same canonical source read-only; local runs use its repo path.
  final spec = File('/input/openapi.json').existsSync()
      ? File('/input/openapi.json')
      : File('../../../web/contracts/openapi.json');
  final schemas = (jsonDecode(spec.readAsStringSync()) as Map)['components']
      ['schemas'] as Map;

  for (final mode in ['absent', 'null', 'string']) {
    test('description $mode in event and nested booking pages', () {
      final json = event();
      if (mode != 'absent')
        json['description'] = mode == 'null' ? null : 'Final match';
      final expected = mode == 'string' ? 'Final match' : null;
      expect(decode<EventResponse>(json).description, expected);
      final events = decode<EventPageResponse>(page(json));
      expect(events.items.single.description, expected);
      expect(
          [events.page, events.size, events.totalElements, events.totalPages],
          [0, 20, 1, 1]);
      final bookings =
          decode<BookingPageResponse>(page(booking()..['event'] = json));
      expect(bookings.items.single.event.description, expected);
      expect(bookings.items.single.participant.id, id);
      expect([
        bookings.page,
        bookings.size,
        bookings.totalElements,
        bookings.totalPages
      ], [
        0,
        20,
        1,
        1
      ]);
    });
  }
  test('empty pages are valid', () {
    final json = {
      'items': <Object?>[],
      'page': 0,
      'size': 20,
      'totalElements': 0,
      'totalPages': 0
    };
    expect(decode<EventPageResponse>(json).items, isEmpty);
    expect(decode<BookingPageResponse>(json).items, isEmpty);
  });
  test('DateTime and all declared event/booking enums round trip', () {
    for (final status
        in schemas['EventResponse']['properties']['status']['enum'] as List) {
      final value = decode<EventResponse>(event()..['status'] = status);
      expect(value.startsAt, DateTime.utc(2026, 10, 1, 10));
      expect(value.endsAt, DateTime.utc(2026, 10, 1, 12));
      expect(value.createdAt.isUtc, isTrue);
      expect(encode(value)['status'], status);
      expect(DateTime.parse(encode(value)['updatedAt'] as String),
          value.updatedAt);
    }
    for (final status
        in schemas['BookingResponse']['properties']['status']['enum'] as List) {
      expect(
          encode(decode<BookingResponse>(booking()..['status'] = status))[
              'status'],
          status);
    }
    expect(() => decode<EventResponse>(event()..['status'] = 'FUTURE'),
        throwsA(anything));
    expect(() => decode<EventResponse>(event()..['startsAt'] = 'invalid'),
        throwsA(anything));
  });

  late Stub stub;
  late Dio dio;
  late ArenaApi client;
  late EventsApi events;
  late BookingsApi bookings;
  setUp(() {
    stub = Stub();
    dio = Dio(BaseOptions(baseUrl: 'http://fixture.invalid'))
      ..httpClientAdapter = stub;
    client = ArenaApi(dio: dio);
    events = client.getEventsApi();
    bookings = client.getBookingsApi();
  });
  tearDown(() => dio.close(force: true));

  test('HTTP lists decode typed pages and send default/explicit pagination',
      () async {
    stub.body = page(event());
    expect((await events.list()).data!.items.single.id, id);
    expect(stub.request.uri.queryParameters, {'page': '0', 'size': '20'});
    await events.list(page: 2, size: 5, status: 'LIVE', sport: 'Tennis');
    expect(stub.request.uri.queryParameters,
        {'page': '2', 'size': '5', 'status': 'LIVE', 'sport': 'Tennis'});
    stub.body = page(booking());
    expect((await bookings.list1()).data!.items.single.participant.displayName,
        'Contract participant');
    expect(stub.request.uri.queryParameters,
        {'scope': 'mine', 'page': '0', 'size': '20'});
    await bookings.list1(
        scope: 'all', eventId: id, status: 'CONFIRMED', page: 3, size: 10);
    expect(stub.request.uri.queryParameters, {
      'scope': 'all',
      'eventId': id,
      'status': 'CONFIRMED',
      'page': '3',
      'size': '10'
    });
    await bookings.list1(scope: null, page: null, size: null);
    expect(stub.request.uri.queryParameters, isEmpty);
  });
  test('HTTP POST/PUT serialize event fields and optional description',
      () async {
    final json = event()
      ..removeWhere(
          (key, _) => !schemas['EventRequest']['properties'].containsKey(key));
    for (final description in [null, 'Final match']) {
      final request = decode<EventRequest>(
          {...json, if (description != null) 'description': description});
      stub
        ..status = 201
        ..body = event();
      final result = await events.create(eventRequest: request);
      expect(result.data!.id, id);
      expect(result.headers.value('location'), '/api/events/$id');
      expect(stub.request.method, 'POST');
      expect(stub.request.path, '/api/events');
      final sent = jsonDecode(stub.sentBody!) as Map;
      expect(sent['title'], json['title']);
      expect(sent['capacity'], 20);
      expect(sent.containsKey('description'), description != null);
      expect(sent['description'], description);
      expect(DateTime.parse(sent['startsAt'] as String),
          DateTime.parse(timestamp));
      stub.status = 200;
      await events.update(id: id, eventRequest: request);
      expect(stub.request.method, 'PUT');
      expect(stub.request.path, '/api/events/$id');
      expect(jsonDecode(stub.sentBody!), sent);
    }
  });
  test('HTTP PATCH and booking POST serialize enum and UUID', () async {
    stub.body = event()..['status'] = 'LIVE';
    await events.changeStatus(
        id: id,
        eventStatusRequest: EventStatusRequest(
            (b) => b.status = EventStatusRequestStatusEnum.LIVE));
    expect(stub.request.method, 'PATCH');
    expect(stub.request.path, '/api/events/$id/status');
    expect(jsonDecode(stub.sentBody!), {'status': 'LIVE'});
    stub
      ..status = 201
      ..body = booking();
    expect(
        (await bookings.create1(
                bookingRequest: BookingRequest((b) => b.eventId = id)))
            .data!
            .status,
        BookingResponseStatusEnum.CONFIRMED);
    expect(stub.request.method, 'POST');
    expect(stub.request.path, '/api/bookings');
    expect(jsonDecode(stub.sentBody!), {'eventId': id});
  });
  test('HTTP DELETE 204 accepts empty body', () async {
    stub
      ..status = 204
      ..body = null;
    final Response<void> response = await events.delete(id: id);
    expect(response.statusCode, 204);
    expect(stub.request.method, 'DELETE');
    expect(stub.request.path, '/api/events/$id');
  });
  test('configured OAuth token reaches the shared Dio adapter', () async {
    stub.body = event();
    client.setOAuthToken('arenaOAuth', 'fixture-token');
    await events.callGet(id: id);
    expect(stub.request.headers['Authorization'], 'Bearer fixture-token');
  });
  for (final status in [400, 401, 409]) {
    test('HTTP $status preserves raw JSON for typed ProblemDetail decoding',
        () async {
      stub
        ..status = status
        ..body = problem(status)
        ..contentType = 'application/problem+json';
      for (final call in <Future<Object?> Function()>[
        () => events.callGet(id: id),
        () => bookings.list1(),
      ]) {
        try {
          await call();
          fail('Expected HTTP error');
        } on DioException catch (error) {
          expect(error.type, DioExceptionType.badResponse);
          expect(error.response!.statusCode, status);
          expect(error.response!.data, isA<Map<String, dynamic>>());
          final typed = decode<ProblemDetail>(error.response!.data!);
          expect(typed.status, status);
          expect(typed.detail, 'Fixture error');
          expect(typed.properties!['traceId']!.asString, 'contract-1');
        }
      }
    });
  }
}
