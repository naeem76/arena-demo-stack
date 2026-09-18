import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arena_mobile/core/api_discovery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';

class TestDiscovery extends Discovery {
  TestDiscovery(super.id);
  bool get listening => hasListeners;
}

Service service({
  String ip = '192.168.1.20',
  String host = 'arena-api.local.',
  String type = '_arena-api._tcp',
  String version = '1',
  String path = '/api',
  String scheme = 'http',
  int port = 8087,
}) => Service(
  name: ip,
  type: type,
  host: host,
  port: port,
  addresses: [InternetAddress(ip)],
  txt: {
    for (final entry in {
      'scheme': scheme,
      'path': path,
      'apiVersion': version,
    }.entries)
      entry.key: Uint8List.fromList(utf8.encode(entry.value)),
  },
);

void main() {
  testWidgets('per-host SRV name resolves to advertised LAN IP and port', (
    tester,
  ) async {
    final browser = TestDiscovery('per-host')
      ..add(
        service(
          host: 'arena-api-192-168-20-199.local.',
          ip: '192.168.20.199',
          port: 18080,
        ),
      );
    final discovery = NsdApiDiscovery(
      start: () async => browser,
      stop: (_) async {},
    );
    final future = discovery.discover();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final result = await future;
    expect(result.source, EndpointSource.mdns);
    expect(result.url, 'http://192.168.20.199:18080');
    expect(browser.listening, isFalse);
  });

  for (final scenario in <String, List<Service>>{
    'found': [service()],
    'found native IP host': [service(host: '192.168.1.20')],
    'no result': [],
    'multiple': [service(), service(ip: '10.0.0.2')],
    'found arbitrary host': [service(host: 'other.local')],
    'foreign type': [service(type: '_http._tcp')],
    'version': [service(version: '2')],
    'path': [service(path: '/other')],
    'scheme': [service(scheme: 'https')],
    'port': [service(port: 0)],
    'loopback': [service(ip: '127.0.0.1')],
    'public': [service(ip: '8.8.8.8')],
    'ipv6': [service(ip: 'fe80::1')],
    'unresolved': [const Service(type: '_arena-api._tcp')],
    'malformed TXT': [
      Service(
        type: '_arena-api._tcp',
        host: 'arena-api.local',
        port: 8080,
        addresses: [InternetAddress('10.0.0.2')],
        txt: {
          'scheme': Uint8List.fromList([255]),
        },
      ),
    ],
  }.entries) {
    testWidgets('${scenario.key}: bounded selection and cleanup', (
      tester,
    ) async {
      final browser = TestDiscovery('test');
      for (final item in scenario.value) {
        browser.add(item);
      }
      var stops = 0;
      final discovery = NsdApiDiscovery(
        start: () async => browser,
        stop: (_) async {
          stops++;
        },
      );
      final future = discovery.discover();
      await tester.pump();
      expect(browser.listening, isTrue);
      await tester.pump(const Duration(seconds: 3));
      final result = await future;
      expect(
        result.source,
        scenario.key.startsWith('found')
            ? EndpointSource.mdns
            : EndpointSource.fallback,
      );
      expect(
        result.url,
        scenario.key.startsWith('found')
            ? 'http://192.168.1.20:8087'
            : 'http://localhost:18080',
      );
      if (scenario.key == 'multiple') {
        expect(result.detail, contains('Multiple'));
      }
      expect(browser.listening, isFalse);
      expect(stops, 1);
      discovery.dispose();
      expect(stops, 1);
    });
  }

  for (final dispose in [false, true]) {
    testWidgets(
      'late startup is stopped after ${dispose ? 'disposal' : 'timeout'}',
      (tester) async {
        final start = Completer<Discovery>();
        final browser = TestDiscovery('late');
        var stops = 0;
        final discovery = NsdApiDiscovery(
          start: () => start.future,
          stop: (_) async {
            stops++;
          },
        );
        final future = discovery.discover();
        if (dispose) discovery.dispose();
        await tester.pump(const Duration(seconds: 3));
        expect((await future).source, EndpointSource.fallback);
        start.complete(browser);
        await tester.pump();
        expect(stops, 1);
        expect(browser.listening, isFalse);
      },
    );
  }

  testWidgets('missing plugin or permission failure falls back immediately', (
    tester,
  ) async {
    for (final error in [
      MissingPluginException(),
      PlatformException(code: 'denied'),
    ]) {
      final discovery = NsdApiDiscovery(start: () async => throw error);
      final future = discovery.discover();
      await tester.pump();
      expect((await future).detail, 'Local discovery unavailable');
      discovery.dispose();
    }
  });

  testWidgets('lost services are excluded and failed stop does not block', (
    tester,
  ) async {
    final browser = TestDiscovery('lost');
    final first = service();
    browser.add(first);
    final discovery = NsdApiDiscovery(
      start: () async => browser,
      stop: (_) async => throw PlatformException(code: 'stop failed'),
    );
    final future = discovery.discover();
    await tester.pump();
    browser.remove(first);
    browser.add(service(ip: '10.0.0.2'));
    await tester.pump(const Duration(seconds: 3));
    expect((await future).url, 'http://10.0.0.2:8087');
    expect(browser.listening, isFalse);
  });

  testWidgets('active disposal detaches listener even when stop hangs', (
    tester,
  ) async {
    final browser = TestDiscovery('active');
    final discovery = NsdApiDiscovery(
      start: () async => browser,
      stop: (_) => Completer<void>().future,
    );
    final future = discovery.discover();
    await tester.pump();
    discovery.dispose();
    expect((await future).source, EndpointSource.fallback);
    expect(browser.listening, isFalse);
  });
}
