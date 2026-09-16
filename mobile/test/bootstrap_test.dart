import 'dart:async';

import 'package:arena_mobile/app.dart';
import 'package:arena_mobile/core/api_discovery.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'core/api/api_boundary_test.dart' show StubAdapter;

class FakeDiscovery implements ApiDiscovery {
  final result = Completer<ApiEndpoint>();
  int calls = 0;
  bool disposed = false;
  @override
  Future<ApiEndpoint> discover() {
    calls++;
    return result.future;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  testWidgets('explicit configuration skips discovery entirely', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configuredApiUrlProvider.overrideWithValue('http://10.0.0.9:9000'),
          apiDiscoveryProvider.overrideWith(
            (ref) => throw StateError('Must not browse'),
          ),
        ],
        child: const ArenaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('http://10.0.0.9:9000'), findsOneWidget);
    expect(find.text('configured: API_BASE_URL'), findsOneWidget);
  });

  for (final endpoint in [
    const ApiEndpoint(
      'http://10.0.0.2:9000',
      EndpointSource.mdns,
      'Local discovery',
    ),
    const ApiEndpoint.fallback('No local result'),
  ]) {
    testWidgets('bootstrap shows loading then ${endpoint.source.name}', (
      tester,
    ) async {
      final fake = FakeDiscovery();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configuredApiUrlProvider.overrideWithValue(null),
            apiDiscoveryProvider.overrideWith((ref) {
              ref.onDispose(fake.dispose);
              return fake;
            }),
          ],
          child: const ArenaApp(),
        ),
      );
      expect(find.text('Looking for local API…'), findsOneWidget);
      fake.result.complete(endpoint);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(fake.calls, 1);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text(endpoint.url), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(fake.disposed, isTrue);
    });
  }

  for (final source in [EndpointSource.mdns, EndpointSource.configured]) {
    test('${source.name} endpoint token policy', () async {
      final container = ProviderContainer.test(
        overrides: [
          apiEndpointProvider.overrideWith(
            (ref) => ApiEndpoint('http://10.0.0.2:9000', source, 'test'),
          ),
          accessTokenProvider.overrideWithValue('existing-session'),
        ],
      );
      await container.read(apiEndpointProvider.future);
      final api = container.read(arenaApiProvider);
      final adapter = StubAdapter({
        'items': [],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      });
      api.dio.httpClientAdapter = adapter;
      await api.getEventsApi().list();
      expect(
        adapter.requests.single.uri.toString(),
        startsWith('http://10.0.0.2:9000/api/events'),
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        source == EndpointSource.mdns ? isNull : 'Bearer existing-session',
      );
    });
  }
}
