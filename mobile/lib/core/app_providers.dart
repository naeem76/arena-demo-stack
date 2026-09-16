import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_boundary.dart';
import 'api_discovery.dart';
import 'auth.dart';

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
    return ApiEndpoint(
      configured.replaceFirst(RegExp(r'/+$'), ''),
      EndpointSource.configured,
      'API_BASE_URL',
    );
  }
  return ref.watch(apiDiscoveryProvider).discover();
});

final apiBaseUrlProvider = Provider<String>(
  (ref) =>
      ref.watch(apiEndpointProvider).asData?.value.url ??
      const ApiEndpoint.fallback('Startup pending').url,
);

final authPlatformProvider = Provider<AuthPlatform>(
  (ref) => NativeAuthPlatform(),
);
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => NativeSessionStorage(),
);
final authServerProvider = Provider<AuthServer>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return HttpAuthServer(dio);
});
final authProvider = NotifierProvider<AuthController, AuthState>(
  () => _BoundAuthController(),
);

class _BoundAuthController extends AuthController {
  _BoundAuthController() : super.bound();
  @override
  AuthState build() {
    platform = ref.read(authPlatformProvider);
    storage = ref.read(sessionStorageProvider);
    server = ref.read(authServerProvider);
    selectedOrigin = () => ref.read(apiEndpointProvider).asData?.value.url;
    ref.listen(apiEndpointProvider, (previous, next) {
      if (previous?.asData?.value.url != next.asData?.value.url) {
        if (previous?.asData != null) {
          invalidate();
        } else if (next.asData != null) {
          restore();
        }
      }
    });
    Future.microtask(() {
      if (ref.mounted && selectedOrigin() != null) restore();
    });
    return super.build();
  }
}

final arenaApiProvider = Provider<ArenaApi>((ref) {
  final origin = ref.watch(apiBaseUrlProvider);
  final api = createArenaApi(
    apiBaseUrl: origin,
    accessToken: () => ref.read(authProvider.notifier).tokenFor(origin),
    onUnauthorized: (token) =>
        ref.read(authProvider.notifier).invalidate(token: token),
  );
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});
