import 'package:arena_api/arena_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_boundary.dart';

final apiBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  ),
);

// Mobile OIDC will supply the current session's token at this boundary.
final accessTokenProvider = Provider<String?>((ref) => null);

final arenaApiProvider = Provider<ArenaApi>((ref) {
  final api = createArenaApi(
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
    accessToken: () => ref.read(accessTokenProvider),
  );
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});
