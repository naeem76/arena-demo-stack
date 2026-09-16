import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const mobileClientId = 'arena-mobile';
const authRedirect = 'com.arena.mobile:/oauth/callback';
const logoutRedirect = 'com.arena.mobile:/signed-out';

void requireSafeOrigin(String origin, {bool debug = kDebugMode}) {
  final uri = Uri.parse(origin);
  final host = uri.host.toLowerCase();
  final parts = host.split('.').map(int.tryParse).toList();
  final ipv4 =
      parts.length == 4 &&
      parts.every((part) => part != null && part >= 0 && part <= 255);
  final local =
      host == 'localhost' ||
      host.endsWith('.local') ||
      host == '::1' ||
      (host.contains(':') &&
          (host.startsWith('fc') ||
              host.startsWith('fd') ||
              host.startsWith('fe80:'))) ||
      (ipv4 &&
          (parts[0] == 10 ||
              parts[0] == 127 ||
              (parts[0] == 192 && parts[1] == 168) ||
              (parts[0] == 169 && parts[1] == 254) ||
              (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31)));
  if (!uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      (uri.scheme != 'https' && !(debug && uri.scheme == 'http' && local))) {
    throw StateError(
      'HTTPS is required outside trusted local debug development.',
    );
  }
}

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class NativeSessionStorage implements SessionStorage {
  static const _key = 'arena.mobile.auth.session.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'arena.mobile.auth'),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

abstract interface class AuthPlatform {
  Future<AuthorizationTokenResponse> authorize(
    AuthorizationTokenRequest request,
  );
  Future<void> endSession(EndSessionRequest request);
}

class NativeAuthPlatform implements AuthPlatform {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  @override
  Future<AuthorizationTokenResponse> authorize(
    AuthorizationTokenRequest request,
  ) => _appAuth.authorizeAndExchangeCode(request);
  @override
  Future<void> endSession(EndSessionRequest request) async {
    await _appAuth.endSession(request);
  }
}

abstract interface class AuthServer {
  Future<Map<String, dynamic>> metadata(String origin);
  Future<Map<String, dynamic>> userinfo(String origin, String token);
}

class HttpAuthServer implements AuthServer {
  final Dio dio;
  HttpAuthServer(this.dio);
  Future<Map<String, dynamic>> _get(
    String origin,
    String path, [
    String? token,
  ]) async {
    requireSafeOrigin(origin);
    final response = await dio.get<Object?>(
      '$origin$path',
      options: Options(
        followRedirects: false,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw StateError('Invalid authentication response.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> metadata(String origin) =>
      _get(origin, '/.well-known/openid-configuration');
  @override
  Future<Map<String, dynamic>> userinfo(String origin, String token) =>
      _get(origin, '/userinfo', token);
}

Map<String, dynamic> _claims(String token) => Map<String, dynamic>.from(
  jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
  ) as Map,
);

class AuthSession {
  final String accessToken, idToken, issuer, origin, sub, name;
  final DateTime expiry;
  AuthSession({
    required this.accessToken,
    required this.idToken,
    required this.issuer,
    required this.origin,
    required this.sub,
    required this.name,
    required this.expiry,
  });
  String encode() => jsonEncode({
    'accessToken': accessToken,
    'idToken': idToken,
    'issuer': issuer,
    'origin': origin,
    'sub': sub,
    'name': name,
    'expiry': expiry.toIso8601String(),
  });
  factory AuthSession.decode(String value) {
    final data = jsonDecode(value) as Map;
    return AuthSession(
      accessToken: data['accessToken'] as String,
      idToken: data['idToken'] as String,
      issuer: data['issuer'] as String,
      origin: data['origin'] as String,
      sub: data['sub'] as String,
      name: data['name'] as String,
      expiry: DateTime.parse(data['expiry'] as String),
    );
  }
}

class AuthState {
  final AuthSession? session;
  final bool busy, hasSignedIn, differentAccount;
  final String? message;
  const AuthState({
    this.session,
    this.busy = false,
    this.hasSignedIn = false,
    this.differentAccount = false,
    this.message,
  });
}

class AuthController extends Notifier<AuthState> {
  AuthController({
    required this.platform,
    required this.storage,
    required this.server,
    required this.selectedOrigin,
    DateTime Function()? now,
    this.debug = kDebugMode,
  }) : now = now ?? DateTime.now;
  AuthController.bound() : now = DateTime.now, debug = kDebugMode;
  late AuthPlatform platform;
  late SessionStorage storage;
  late AuthServer server;
  late String? Function() selectedOrigin;
  final DateTime Function() now;
  final bool debug;
  Timer? _timer;
  int _generation = 0;
  Future<void> _storageQueue = Future.value();
  @override
  AuthState build() {
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
    });
    return const AuthState();
  }

  Future<void> _store(Future<void> Function() operation) {
    final result = _storageQueue.then((_) => operation());
    _storageQueue = result.catchError((Object _) {});
    return result;
  }

  AuthorizationServiceConfiguration? _configuration(String origin) =>
      debug && Uri.parse(origin).scheme == 'http'
      ? AuthorizationServiceConfiguration(
          authorizationEndpoint: '$origin/oauth2/authorize',
          tokenEndpoint: '$origin/oauth2/token',
          endSessionEndpoint: '$origin/connect/logout',
        )
      : null;
  String _origin() {
    final origin = selectedOrigin();
    if (origin == null) throw StateError('Select an API endpoint first.');
    requireSafeOrigin(origin, debug: debug);
    return origin;
  }

  Future<String> _issuer(String origin) async {
    final metadata = await server.metadata(origin);
    final issuer = metadata['issuer'] as String;
    requireSafeOrigin(issuer, debug: debug);
    if (_configuration(origin) == null) {
      for (final key in [
        'authorization_endpoint',
        'token_endpoint',
        'jwks_uri',
        'end_session_endpoint',
      ]) {
        final endpoint = Uri.parse(metadata[key] as String);
        if (endpoint.scheme != 'https') {
          throw StateError('HTTPS discovery required.');
        }
      }
    }
    return issuer;
  }

  Future<AuthSession> _verify(AuthSession candidate) async {
    if (candidate.origin != selectedOrigin() ||
        !candidate.expiry.isAfter(now())) {
      throw StateError('Session expired or endpoint changed.');
    }
    requireSafeOrigin(candidate.origin, debug: debug);
    // Claims are only consumed AFTER the backend validates this exact bearer.
    final user = await server.userinfo(candidate.origin, candidate.accessToken);
    final claims = _claims(candidate.accessToken);
    if (user['sub'] is! String ||
        user['sub'] != claims['sub'] ||
        claims['iss'] != candidate.issuer) {
      throw StateError('Invalid identity.');
    }
    final roles = claims['roles'];
    if (roles is! List || !roles.contains('ADMIN')) throw const _Forbidden();
    final tokenExpiry = DateTime.fromMillisecondsSinceEpoch(
      (claims['exp'] as num).toInt() * 1000,
    );
    final expiry = candidate.expiry.isBefore(tokenExpiry)
        ? candidate.expiry
        : tokenExpiry;
    if (!expiry.isAfter(now())) throw StateError('Expired session.');
    return AuthSession(
      accessToken: candidate.accessToken,
      idToken: candidate.idToken,
      issuer: candidate.issuer,
      origin: candidate.origin,
      sub: user['sub'] as String,
      name: user['name'] as String? ?? user['sub'] as String,
      expiry: expiry,
    );
  }

  bool _current(int generation, String origin) =>
      generation == _generation && selectedOrigin() == origin;
  Future<void> _accept(AuthSession session, int generation) async {
    if (!_current(generation, session.origin)) return;
    await _store(() => storage.write(session.encode()));
    if (!_current(generation, session.origin)) return;
    state = AuthState(session: session, hasSignedIn: true);
    _timer?.cancel();
    _timer = Timer(
      session.expiry.difference(now()),
      () => invalidate(token: session.accessToken),
    );
  }

  Future<void> restore() async {
    if (state.busy) return;
    final generation = ++_generation;
    state = const AuthState(busy: true);
    try {
      final origin = _origin();
      final raw = await storage.read();
      if (generation != _generation) return;
      if (raw == null) {
        state = const AuthState();
        return;
      }
      final stored = AuthSession.decode(raw);
      if (stored.origin != origin || !stored.expiry.isAfter(now())) {
        throw StateError('Session expired or endpoint changed.');
      }
      if (await _issuer(origin) != stored.issuer) {
        throw StateError('Issuer changed.');
      }
      if (!_current(generation, origin)) return;
      await _accept(await _verify(stored), generation);
    } catch (_) {
      if (generation == _generation) await invalidate();
    }
  }

  Future<void> signIn() async {
    if (state.busy) return;
    final previous = state;
    final generation = ++_generation;
    state = AuthState(busy: true, hasSignedIn: previous.hasSignedIn);
    try {
      final origin = _origin();
      final issuer = await _issuer(origin);
      if (!_current(generation, origin)) return;
      final configuration = _configuration(origin);
      final result = await platform.authorize(
        AuthorizationTokenRequest(
          mobileClientId,
          authRedirect,
          scopes: const ['openid', 'profile', 'api.access'],
          serviceConfiguration: configuration,
          discoveryUrl: configuration == null
              ? '$origin/.well-known/openid-configuration'
              : null,
          allowInsecureConnections: debug && configuration != null,
          promptValues: previous.differentAccount ? const ['login'] : null,
        ),
      );
      if (!_current(generation, origin)) return;
      final id = result.idToken!;
      final idClaims = _claims(id);
      final aud = idClaims['aud'];
      if (idClaims['iss'] != issuer ||
          !(aud == mobileClientId ||
              aud is List && aud.contains(mobileClientId))) {
        throw StateError('ID token issuer or audience mismatch.');
      }
      final session = await _verify(
        AuthSession(
          accessToken: result.accessToken!,
          idToken: id,
          issuer: issuer,
          origin: origin,
          sub: '',
          name: '',
          expiry: result.accessTokenExpirationDateTime!,
        ),
      );
      await _accept(session, generation);
    } on FlutterAppAuthUserCancelledException {
      if (generation == _generation) {
        state = AuthState(
          hasSignedIn: previous.hasSignedIn,
          differentAccount: previous.differentAccount,
          message: 'Sign-in cancelled.',
        );
      }
    } catch (error) {
      if (generation != _generation) return;
      await invalidate(
        message: error is _Forbidden
            ? 'Administrator access required. Sign in with a different account.'
            : 'Sign-in failed. Please try again.',
        differentAccount: error is _Forbidden,
        logout: error is _Forbidden,
      );
    }
  }

  String? tokenFor(String origin) {
    requireSafeOrigin(origin, debug: debug);
    final session = state.session;
    if (session == null) return null;
    if (session.origin != selectedOrigin() || !session.expiry.isAfter(now())) {
      unawaited(invalidate(token: session.accessToken));
      return null;
    }
    if (session.origin != origin) return null;
    return session.accessToken;
  }

  Future<void> invalidate({
    String? token,
    String message = 'Session ended. Sign in again.',
    bool differentAccount = false,
    bool logout = false,
  }) async {
    if (token != null && state.session?.accessToken != token) return;
    final generation = ++_generation;
    _timer?.cancel();
    state = AuthState(
      hasSignedIn: !logout && state.hasSignedIn,
      message: message,
      differentAccount: differentAccount,
    );
    try {
      await _store(storage.clear);
    } catch (_) {
      if (generation != _generation) return;
      try {
        await _store(() => storage.write('null'));
      } catch (_) {
        if (generation != _generation) return;
        state = AuthState(
          hasSignedIn: state.hasSignedIn,
          message: 'Could not clear the saved session. Clear app data before sharing this device.',
        );
      }
    }
  }

  Future<void> logout() async {
    final session = state.session;
    await invalidate(
      logout: true,
      message: 'Signed out.',
      differentAccount: true,
    );
    if (session == null || session.origin != selectedOrigin()) return;
    try {
      requireSafeOrigin(session.origin, debug: debug);
      final configuration = _configuration(session.origin);
      await platform.endSession(
        EndSessionRequest(
          idTokenHint: session.idToken,
          postLogoutRedirectUrl: logoutRedirect,
          serviceConfiguration: configuration,
          discoveryUrl: configuration == null
              ? '${session.origin}/.well-known/openid-configuration'
              : null,
          allowInsecureConnections: debug && configuration != null,
        ),
      );
    } on FlutterAppAuthUserCancelledException {
      // Local logout is complete even when browser logout is cancelled.
    } catch (_) {
      // Local logout is complete even when the provider cannot be reached.
    }
  }
}

class _Forbidden implements Exception {
  const _Forbidden();
}
