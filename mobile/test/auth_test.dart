import 'dart:async';

import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/auth.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

void main() {
  test('normalizes a configured origin before auth and API use', () async {
    final scoped = ProviderContainer.test(
      overrides: [configuredApiUrlProvider.overrideWithValue('$testOrigin/')],
    );
    expect((await scoped.read(apiEndpointProvider.future)).url, testOrigin);
    expect(scoped.read(apiBaseUrlProvider), testOrigin);
  });
  late MemoryStorage storage;
  late FakeAuthPlatform platform;
  late FakeAuthServer server;
  late ProviderContainer container;
  late AuthController auth;
  late String origin;
  setUp(() {
    storage = MemoryStorage();
    platform = FakeAuthPlatform();
    server = FakeAuthServer();
    origin = testOrigin;
    container = ProviderContainer.test(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(
            platform: platform,
            storage: storage,
            server: server,
            selectedOrigin: () => origin,
          ),
        ),
      ],
    );
    auth = container.read(authProvider.notifier);
  });
  test(
    'logout while native sign-in is pending cannot resurrect tokens',
    () async {
      platform.gate = Completer<void>();
      final pending = auth.signIn();
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      platform.gate!.complete();
      await pending;
      expect(container.read(authProvider).session, isNull);
      expect(storage.value, isNull);
      expect(server.verified, isEmpty);
    },
  );
  test(
    'logout during restore metadata prevents subsequent bearer forwarding',
    () async {
      await auth.signIn();
      server.verified.clear();
      server.metadataGate = Completer<void>();
      final pending = auth.restore();
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      server.metadataGate!.complete();
      await pending;
      expect(server.verified, isEmpty);
      expect(storage.value, isNull);
    },
  );
  test(
    'per-request expiry check works even before timer is dispatched',
    () async {
      var clock = DateTime.now();
      final provider = NotifierProvider<AuthController, AuthState>(
        () => AuthController(
          platform: platform,
          storage: storage,
          server: server,
          selectedOrigin: () => origin,
          now: () => clock,
        ),
      );
      final controller = container.read(provider.notifier);
      await controller.signIn();
      clock = clock.add(const Duration(minutes: 16));
      expect(controller.tokenFor(origin), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(storage.value, isNull);
      expect(container.read(provider).hasSignedIn, isTrue);
    },
  );
  test(
    'failed deletion writes a signed-out marker that cannot restore a session',
    () async {
      await auth.signIn();
      storage.failClear = true;
      await auth.logout();
      expect(container.read(authProvider).session, isNull);
      expect(auth.tokenFor(origin), isNull);
      expect(storage.value, 'null');
      storage.failClear = false;
      await auth.restore();
      expect(container.read(authProvider).session, isNull);
      expect(storage.value, isNull);
    },
  );
  test(
    'reports when stored-session deletion and overwrite both fail',
    () async {
      await auth.signIn();
      storage.failClear = true;
      storage.failWrite = true;
      await auth.logout();
      expect(container.read(authProvider).session, isNull);
      expect(auth.tokenFor(origin), isNull);
      expect(
        container.read(authProvider).message,
        contains('Could not clear the saved session'),
      );
    },
  );
  test(
    'an old API client cannot read or invalidate the current origin session',
    () async {
      await auth.signIn();
      final token = auth.tokenFor(origin);
      expect(auth.tokenFor('http://10.0.0.99:9000'), isNull);
      expect(auth.tokenFor(origin), token);
      expect(storage.value, isNotNull);
    },
  );
  test('admin sign-in validates bearer before identity and persists no refresh token', () async {
    await auth.signIn();
    expect(container.read(authProvider).session?.name, 'Arena Administrator');
    expect(server.verified, [auth.tokenFor(origin)]);
    expect(storage.value, isNot(contains('refresh')));
    expect(
      platform.request?.serviceConfiguration?.authorizationEndpoint,
      '$origin/oauth2/authorize',
    );
    expect(platform.request?.discoveryUrl, isNull);
    expect(platform.request?.allowInsecureConnections, isTrue);
    expect(platform.request?.scopes, ['openid', 'profile', 'api.access']);
    expect(platform.request?.clientSecret, isNull);
  });
  test(
    'USER is forbidden and next sign-in explicitly selects another account',
    () async {
      platform.roles = ['USER'];
      await auth.signIn();
      expect(container.read(authProvider).session, isNull);
      expect(storage.value, isNull);
      expect(container.read(authProvider).differentAccount, isTrue);
      await auth.signIn();
      expect(platform.request?.promptValues, ['login']);
    },
  );
  for (final failure in [
    'issuer',
    'audience',
    'subject',
    'backend',
    'platform',
    'storage',
  ]) {
    test('$failure failure retains no session', () async {
      switch (failure) {
        case 'issuer':
          platform.issuer = 'http://wrong.local';
        case 'audience':
          platform.audience = 'other-client';
        case 'subject':
          server.sub = 'other';
        case 'backend':
          server.error = StateError('401 tampered token');
        case 'platform':
          platform.error = StateError('native failure');
        case 'storage':
          storage.failWrite = true;
      }
      await auth.signIn();
      expect(container.read(authProvider).session, isNull);
      expect(storage.value, isNull);
      expect(container.read(authProvider).busy, isFalse);
    });
  }
  test('cancellation has distinct message', () async {
    platform.error = FlutterAppAuthUserCancelledException(
      code: 'cancel',
      platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
    );
    await auth.signIn();
    expect(container.read(authProvider).message, 'Sign-in cancelled.');
  });
  test('restore revalidates bearer and replaces stored identity', () async {
    await auth.signIn();
    await auth.restore();
    expect(server.verified.length, 2);
    expect(container.read(authProvider).session?.name, 'Arena Administrator');
  });
  for (final failure in [
    'expired',
    'corrupt',
    'origin',
    'read',
    'revoked',
    'role',
  ]) {
    test('restore $failure fails closed', () async {
      await auth.signIn();
      final previous = AuthSession.decode(storage.value!);
      switch (failure) {
        case 'expired':
          storage.value = AuthSession(
            accessToken: previous.accessToken,
            idToken: previous.idToken,
            issuer: previous.issuer,
            origin: previous.origin,
            sub: previous.sub,
            name: previous.name,
            expiry: DateTime(2000),
          ).encode();
        case 'corrupt':
          storage.value = '{';
        case 'origin':
          origin = 'http://10.0.0.3:9000';
        case 'read':
          storage.failRead = true;
        case 'revoked':
          server.error = StateError('401');
        case 'role':
          storage.value = AuthSession(
            accessToken: jwt({
              'sub': 'admin',
              'iss': testIssuer,
              'roles': ['USER'],
              'exp': previous.expiry.millisecondsSinceEpoch ~/ 1000,
            }),
            idToken: previous.idToken,
            issuer: previous.issuer,
            origin: previous.origin,
            sub: previous.sub,
            name: previous.name,
            expiry: previous.expiry,
          ).encode();
      }
      server.verified.clear();
      await auth.restore();
      expect(container.read(authProvider).session, isNull);
      expect(storage.value, isNull);
      if (['expired', 'corrupt', 'origin', 'read'].contains(failure)) {
        expect(server.verified, isEmpty);
      }
    });
  }
  test(
    'release/profile HTTP rejected before metadata or native auth',
    () async {
      final provider = NotifierProvider<AuthController, AuthState>(
        () => AuthController(
          platform: platform,
          storage: storage,
          server: server,
          selectedOrigin: () => origin,
          debug: false,
        ),
      );
      await container.read(provider.notifier).signIn();
      expect(platform.request, isNull);
      expect(server.metadataCalls, 0);
      expect(
        () => container.read(provider.notifier).tokenFor(origin),
        throwsStateError,
      );
    },
  );
  test('HTTPS uses discovery without manual overrides', () async {
    origin = 'https://arena.example';
    server.issuer = origin;
    platform.issuer = origin;
    await auth.signIn();
    expect(platform.request?.serviceConfiguration, isNull);
    expect(
      platform.request?.discoveryUrl,
      '$origin/.well-known/openid-configuration',
    );
    expect(platform.request?.allowInsecureConnections, isFalse);
  });
  test('late 401 cannot clear newer sign-in; current 401 requests reauthentication', () async {
    await auth.signIn();
    final old = auth.tokenFor(origin)!;
    await auth.signIn();
    final current = auth.tokenFor(origin)!;
    await auth.invalidate(token: old);
    expect(auth.tokenFor(origin), current);
    await auth.invalidate(token: current);
    expect(storage.value, isNull);
    expect(container.read(authProvider).hasSignedIn, isTrue);
  });
  test(
    'origin changes prevent token forwarding and clear persisted session',
    () async {
      await auth.signIn();
      origin = 'http://10.0.0.3:9000';
      expect(auth.tokenFor(origin), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(storage.value, isNull);
    },
  );
  test(
    'logout clears locally despite browser failure and preserves hint',
    () async {
      await auth.signIn();
      final hint = container.read(authProvider).session!.idToken;
      platform.logoutError = StateError('unreachable');
      await auth.logout();
      expect(storage.value, isNull);
      expect(container.read(authProvider).hasSignedIn, isFalse);
      expect(platform.logoutRequest?.idTokenHint, hint);
      expect(platform.logoutRequest?.postLogoutRedirectUrl, logoutRedirect);
    },
  );
}
