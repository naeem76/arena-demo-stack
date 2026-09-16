import 'package:arena_mobile/core/auth.dart';
import 'package:arena_mobile/core/api/api_boundary.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';
import 'core/api/api_boundary_test.dart' show StubAdapter;

void main() {
  test('public metadata has no bearer and userinfo uses exact bearer without redirects', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final adapter = StubAdapter({'issuer': testIssuer});
    dio.httpClientAdapter = adapter;
    final server = HttpAuthServer(dio);
    expect((await server.metadata(testOrigin))['issuer'], testIssuer);
    await server.userinfo(testOrigin, 'verified-by-server');
    expect(
      adapter.requests[0].uri.toString(),
      '$testOrigin/.well-known/openid-configuration',
    );
    expect(adapter.requests[0].headers['Authorization'], isNull);
    expect(adapter.requests[1].uri.toString(), '$testOrigin/userinfo');
    expect(
      adapter.requests[1].headers['Authorization'],
      'Bearer verified-by-server',
    );
    expect(
      adapter.requests.every((request) => !request.followRedirects),
      isTrue,
    );
  });
  test('profile/release boundary rejects HTTP before reading token or sending request', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final adapter = StubAdapter({});
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      ApiBoundaryInterceptor(
        apiBaseUrl: testOrigin,
        debug: false,
        accessToken: () => throw StateError('must not read token'),
      ),
    );
    await expectLater(
      dio.get('$testOrigin/api/events'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    '401 callbacks carry the token actually sent, no mutation retry',
    () async {
      final tokens = <String>[];
      final api = createArenaApi(
        apiBaseUrl: testOrigin,
        accessToken: () => 'sent-token',
        onUnauthorized: tokens.add,
      );
      addTearDown(api.dio.close);
      final adapter = StubAdapter({}, status: 401);
      api.dio.httpClientAdapter = adapter;
      await expectLater(
        api.dio.post('$testOrigin/api/events'),
        throwsA(isA<DioException>()),
      );
      expect(tokens, ['sent-token']);
      expect(adapter.requests.length, 1);
    },
  );
  test('boundary strips supplied authorization on other origins', () async {
    final api = createArenaApi(
      apiBaseUrl: testOrigin,
      accessToken: () => 'session',
    );
    addTearDown(api.dio.close);
    final adapter = StubAdapter({});
    api.dio.httpClientAdapter = adapter;
    await api.dio.get(
      'https://other.example/api/events',
      options: Options(headers: {'authorization': 'Bearer unsafe'}),
    );
    expect(
      adapter.requests.single.headers.keys.any(
        (key) => key.toLowerCase() == 'authorization',
      ),
      isFalse,
    );
  });
  test('debug HTTP restricted to local addresses; HTTPS works in release', () {
    for (final origin in [
      'http://10.0.0.2:9000',
      'http://arena.local:18080',
      'http://localhost:18080',
    ]) {
      expect(() => requireSafeOrigin(origin), returnsNormally);
      expect(() => requireSafeOrigin(origin, debug: false), throwsStateError);
    }
    expect(() => requireSafeOrigin('http://public.example'), throwsStateError);
    expect(
      () => requireSafeOrigin('https://arena.example', debug: false),
      returnsNormally,
    );
  });
}
