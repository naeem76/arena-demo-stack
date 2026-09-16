import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/api/api_boundary.dart';
import 'package:arena_mobile/core/api/api_error.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.body, {this.status = 200, this.failure});

  final Object? body;
  final int status;
  final DioExceptionType? failure;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failure != null) {
      throw DioException(
        requestOptions: options,
        type: failure!,
        message: 'unsafe transport secret',
      );
    }
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<ApiError> caughtError(Future<Object?> request) async {
  try {
    await request;
  } catch (error) {
    return describeApiError(error);
  }
  fail('Expected the request to fail');
}

void main() {
  test('Riverpod wiring uses the configured API and session token', () async {
    final container = ProviderContainer.test(
      overrides: [
        apiBaseUrlProvider.overrideWithValue('https://configured.arena.test'),
        accessTokenProvider.overrideWithValue('session-token'),
      ],
    );
    final api = container.read(arenaApiProvider);
    final adapter = StubAdapter({
      'items': [],
      'page': 0,
      'size': 20,
      'totalElements': 0,
      'totalPages': 0,
    });
    api.dio.httpClientAdapter = adapter;

    final response = await api.getEventsApi().list();

    expect(response.data!.items, isEmpty);
    expect(adapter.requests.single.uri.host, 'configured.arena.test');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer session-token',
    );
  });

  for (final collection in ['events', 'bookings']) {
    for (final malformed in <String, Object?>{
      'non-map': [],
      'missing items': <String, Object?>{},
      'null items': {'items': null},
      'wrong items type': {'items': {}},
      'null body': null,
    }.entries) {
      test(
        '$collection rejects ${malformed.key} before deserialization',
        () async {
          final api = createArenaApi(
            apiBaseUrl: 'https://arena.test',
            accessToken: () => null,
          );
          api.dio.httpClientAdapter = StubAdapter(malformed.value);
          addTearDown(() => api.dio.close());
          final error = await caughtError(
            collection == 'events'
                ? api.getEventsApi().list()
                : api.getBookingsApi().list1(),
          );
          expect(
            error.message,
            'The API returned an invalid page. Please try again.',
          );
        },
      );
    }

    test(
      '$collection valid empty page reaches generated deserializer',
      () async {
        final api = createArenaApi(
          apiBaseUrl: 'https://arena.test',
          accessToken: () => null,
        );
        api.dio.httpClientAdapter = StubAdapter({
          'items': [],
          'page': 0,
          'size': 20,
          'totalElements': 0,
          'totalPages': 0,
        });
        addTearDown(() => api.dio.close());
        if (collection == 'events') {
          expect((await api.getEventsApi().list()).data!.items, isEmpty);
        } else {
          expect((await api.getBookingsApi().list1()).data!.items, isEmpty);
        }
      },
    );
  }

  test(
    'guard accepts list items and ignores mutations, details and other origins',
    () async {
      final api = createArenaApi(
        apiBaseUrl: 'https://arena.test',
        accessToken: () => null,
      );
      addTearDown(() => api.dio.close());
      api.dio.httpClientAdapter = StubAdapter({
        'items': [1],
      });
      expect((await api.dio.get<Object?>('/api/events')).statusCode, 200);
      api.dio.httpClientAdapter = StubAdapter({'id': 'record'});
      for (final path in [
        '/api/events/record',
        '/api/diagnostics',
        '/api/events-extra',
        'https://other.test/api/events',
      ]) {
        expect((await api.dio.get<Object?>(path)).statusCode, 200);
      }
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        expect(
          (await api.dio.request<Object?>(
            '/api/events',
            options: Options(method: method),
          )).statusCode,
          200,
        );
      }
      api.dio.httpClientAdapter = StubAdapter(null, status: 204);
      expect((await api.dio.get<Object?>('/api/events')).statusCode, 204);
      expect((await api.getEventsApi().delete(id: 'record')).statusCode, 204);
    },
  );

  test(
    'token is fresh and scoped by origin, port and API path segment',
    () async {
      var token = 'first-secret';
      var reads = 0;
      final api = createArenaApi(
        apiBaseUrl: 'https://arena.test/service/',
        accessToken: () {
          reads++;
          return token;
        },
      );
      final adapter = StubAdapter({});
      api.dio.httpClientAdapter = adapter;
      addTearDown(() => api.dio.close());
      for (final path in [
        'https://other.test/service/api/x',
        'http://arena.test/service/api/x',
        'https://arena.test:444/service/api/x',
        '/service/apix',
        '/service/api-extra',
        '/api/x',
      ]) {
        await api.dio.get<Object?>(
          Uri.parse('https://arena.test').resolve(path).toString(),
        );
        expect(adapter.requests.last.headers['Authorization'], isNull);
      }
      expect(reads, 0);
      for (final path in ['/service/api', '/service/api/x?next=other']) {
        await api.dio.get<Object?>(
          Uri.parse('https://arena.test').resolve(path).toString(),
        );
        expect(adapter.requests.last.headers['Authorization'], 'Bearer $token');
        expect(adapter.requests.last.followRedirects, isFalse);
        token = 'updated-secret';
      }
      expect(reads, 2);
      token = '';
      await api.dio.get<Object?>('https://arena.test/service/api/x');
      expect(adapter.requests.last.headers['Authorization'], isNull);
      expect(api.dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    },
  );

  for (final entry in {
    401: 'Your session has expired. Sign in again to continue.',
    403: 'Your account does not have permission to perform this action.',
    404: 'This record could not be found. It may have been removed.',
    500: 'The server could not complete this request. Please try again.',
    503: 'The server could not complete this request. Please try again.',
  }.entries) {
    test(
      '${entry.key} masks unsafe bodies and never retries mutation',
      () async {
        final api = createArenaApi(
          apiBaseUrl: 'https://arena.test',
          accessToken: () => 'token-secret',
        );
        final adapter = StubAdapter({
          'detail': 'unsafe stack secret',
          'errors': [
            {'field': 'secret', 'message': 'unsafe'},
          ],
        }, status: entry.key);
        api.dio.httpClientAdapter = adapter;
        addTearDown(() => api.dio.close());
        final error = await caughtError(api.dio.post<Object?>('/api/events'));
        expect(error.message, entry.value);
        expect(error.fields, isEmpty);
        expect(error.toString(), isNot(contains('secret')));
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  for (final status in [400, 409]) {
    test(
      '$status preserves detail and valid field violations, including text responses',
      () async {
        final api = createArenaApi(
          apiBaseUrl: 'https://arena.test',
          accessToken: () => null,
        );
        api.dio.httpClientAdapter = StubAdapter({
          'detail': 'Check your input.',
          'errors': [
            {'field': 'name', 'message': 'Required'},
            {'field': 'name', 'message': 'Too short'},
            {'field': 'count', 'message': 9},
            null,
          ],
        }, status: status);
        addTearDown(() => api.dio.close());
        for (final type in [ResponseType.json, ResponseType.plain]) {
          final error = await caughtError(
            api.dio.get<Object?>(
              '/api/events',
              options: Options(responseType: type),
            ),
          );
          expect(error.message, 'Check your input.');
          expect(error.fields, {'name': 'Too short'});
          expect(() => error.fields['new'] = 'value', throwsUnsupportedError);
        }
      },
    );
  }

  test('unusable request error body has safe fallback', () async {
    final api = createArenaApi(
      apiBaseUrl: 'https://arena.test',
      accessToken: () => null,
    );
    addTearDown(() => api.dio.close());
    for (final body in [
      null,
      '<html>unsafe</html>',
      {'detail': 123},
      [],
    ]) {
      api.dio.httpClientAdapter = StubAdapter(body, status: 400);
      final error = await caughtError(api.dio.get<Object?>('/api/events'));
      expect(
        error.message,
        'The request could not be completed. Check your input and try again.',
      );
      expect(error.fields, isEmpty);
    }
  });

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$type has safe connection message', () async {
      final api = createArenaApi(
        apiBaseUrl: 'https://arena.test',
        accessToken: () => 'secret',
      );
      api.dio.httpClientAdapter = StubAdapter(null, failure: type);
      addTearDown(() => api.dio.close());
      final error = await caughtError(api.dio.get<Object?>('/api/events'));
      expect(
        error.message,
        'We could not reach the API. Check your connection and try again.',
      );
      expect(error.toString(), isNot(contains('secret')));
    });
  }

  test('unknown errors mask causes and already-safe errors are preserved', () {
    expect(
      describeApiError(StateError('secret')).message,
      'Something went wrong. Please try again.',
    );
    final safe = ApiError('Safe');
    expect(describeApiError(safe), same(safe));
  });
}
