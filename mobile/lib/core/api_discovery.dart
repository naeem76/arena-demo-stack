import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nsd/nsd.dart' as nsd;

enum EndpointSource { configured, mdns, fallback }

class ApiEndpoint {
  const ApiEndpoint(this.url, this.source, this.detail);

  const ApiEndpoint.fallback(String reason)
    : this('http://localhost:8080', EndpointSource.fallback, reason);

  final String url;
  final EndpointSource source;
  final String detail;
}

abstract interface class ApiDiscovery {
  Future<ApiEndpoint> discover();
  void dispose();
}

/// One startup browse. The deadline includes native startup and IP resolution.
class NsdApiDiscovery implements ApiDiscovery {
  NsdApiDiscovery({
    this.window = const Duration(seconds: 3),
    Future<nsd.Discovery> Function()? start,
    Future<void> Function(nsd.Discovery)? stop,
  }) : _start = start ?? _startNative,
       _stop = stop ?? nsd.stopDiscovery;

  static Future<nsd.Discovery> _startNative() => nsd.startDiscovery(
    '_arena-api._tcp',
    autoResolve: true,
    ipLookupType: nsd.IpLookupType.any,
  );

  final Duration window;
  final Future<nsd.Discovery> Function() _start;
  final Future<void> Function(nsd.Discovery) _stop;
  final _result = Completer<ApiEndpoint>();
  nsd.Discovery? _browser;
  Timer? _timer;
  bool _started = false;
  Set<String> _candidates = {};

  @override
  Future<ApiEndpoint> discover() {
    if (!_started && !_result.isCompleted) {
      _started = true;
      _timer = Timer(window, () {
        final candidates = _candidates;
        _finish(
          candidates.length == 1
              ? ApiEndpoint(
                  candidates.single,
                  EndpointSource.mdns,
                  'Local discovery',
                )
              : ApiEndpoint.fallback(
                  candidates.isEmpty
                      ? 'No eligible local API within startup deadline'
                      : 'Multiple local API candidates; set API_BASE_URL',
                ),
        );
      });
      unawaited(_open());
    }
    return _result.future;
  }

  Future<void> _open() async {
    try {
      final browser = await _start();
      if (_result.isCompleted) {
        // Native startup can complete after timeout or widget disposal.
        unawaited(_stopSafely(browser));
        return;
      }
      _browser = browser;
      browser.addListener(_update);
      _update();
    } catch (_) {
      _finish(const ApiEndpoint.fallback('Local discovery unavailable'));
    }
  }

  void _update() {
    _candidates = {for (final service in _browser!.services) ..._urls(service)};
  }

  void _finish(ApiEndpoint endpoint) {
    if (_result.isCompleted) return;
    _timer?.cancel();
    final browser = _browser;
    if (browser != null) {
      browser.removeListener(_update);
      _browser = null;
      // A stalled platform stop must never hold up the application.
      unawaited(_stopSafely(browser));
    }
    _result.complete(endpoint);
  }

  Future<void> _stopSafely(nsd.Discovery browser) async {
    try {
      await _stop(browser);
    } catch (_) {
      // Best-effort native cleanup; the Dart listener is already detached.
    }
  }

  @override
  void dispose() =>
      _finish(const ApiEndpoint.fallback('Local discovery cancelled'));

  static Iterable<String> _urls(nsd.Service service) {
    final type = service.type?.replaceFirst(RegExp(r'\.$'), '');
    final port = service.port;
    // SRV names vary per advertiser; use resolved addresses, not host identity.
    if (!const {'_arena-api._tcp', '_arena-api._tcp.local'}.contains(type) ||
        port == null ||
        port < 1 ||
        port > 65535) {
      return const [];
    }
    try {
      String? txt(String key) {
        final bytes = service.txt?[key];
        return bytes == null ? null : utf8.decode(bytes);
      }

      if (txt('scheme') != 'http' ||
          txt('path') != '/api' ||
          txt('apiVersion') != '1') {
        return const [];
      }
    } on FormatException {
      return const [];
    }
    return [
      for (final address in service.addresses ?? <InternetAddress>[])
        if (_isLanV4(address))
          Uri(scheme: 'http', host: address.address, port: port).toString(),
    ];
  }

  static bool _isLanV4(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
}
