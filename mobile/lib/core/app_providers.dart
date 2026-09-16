import 'package:arena_api/arena_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_boundary.dart';
import 'api_discovery.dart';

final configuredApiUrlProvider = Provider<String?>(
  (ref) => const bool.hasEnvironment('API_BASE_URL')
      ? const String.fromEnvironment('API_BASE_URL')
      : null,
);

final apiDiscoveryProvider = Provider<ApiDiscovery>((ref) {
  final discovery = NsdApiDiscovery();
  ref.onDispose(discovery.dispose);
  return discovery;
});

final apiEndpointProvider = FutureProvider<ApiEndpoint>((ref) {
  final configured = ref.watch(configuredApiUrlProvider);
  if (configured != null) {
    return ApiEndpoint(configured, EndpointSource.configured, 'API_BASE_URL');
  }
  return ref.watch(apiDiscoveryProvider).discover();
});

final apiBaseUrlProvider = Provider<String>(
  (ref) =>
      ref.watch(apiEndpointProvider).asData?.value.url ??
      const ApiEndpoint.fallback('Startup pending').url,
);

// Mobile OIDC will supply the current session's token at this boundary.
final accessTokenProvider = Provider<String?>((ref) => null);

final arenaApiProvider = Provider<ArenaApi>((ref) {
  final api = createArenaApi(
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
    // Discovery is a connection hint, never an authenticated issuer binding.
    accessToken: () =>
        ref.read(apiEndpointProvider).asData?.value.source ==
            EndpointSource.mdns
        ? null
        : ref.read(accessTokenProvider),
  );
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});
