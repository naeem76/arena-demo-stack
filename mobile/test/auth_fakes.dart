import 'dart:convert';
import 'dart:async';

import 'package:arena_mobile/core/auth.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

const testOrigin = 'http://10.0.0.2:9000';
const testIssuer = 'http://localhost:18080';
String jwt(Map<String, Object> claims) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';

class MemoryStorage implements SessionStorage {
  String? value;
  bool failRead = false, failWrite = false, failClear = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('storage');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('storage');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage');
    value = null;
  }
}

class FakeAuthPlatform implements AuthPlatform {
  Completer<void>? gate;
  Object? error, logoutError;
  AuthorizationTokenRequest? request;
  EndSessionRequest? logoutRequest;
  String issuer = testIssuer;
  Object audience = mobileClientId;
  List<String> roles = ['ADMIN'];
  int serial = 0;
  DateTime expiry = DateTime.now().add(const Duration(minutes: 15));
  @override
  Future<AuthorizationTokenResponse> authorize(
    AuthorizationTokenRequest request,
  ) async {
    this.request = request;
    await gate?.future;
    if (error != null) throw error!;
    return AuthorizationTokenResponse(
      jwt({
        'sub': 'admin',
        'iss': testIssuer,
        'roles': roles,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'serial': serial++,
      }),
      null,
      expiry,
      jwt({'iss': issuer, 'aud': audience}),
      'Bearer',
      request.scopes,
      null,
      null,
    );
  }

  @override
  Future<void> endSession(EndSessionRequest request) async {
    logoutRequest = request;
    if (logoutError != null) throw logoutError!;
  }
}

class FakeAuthServer implements AuthServer {
  Completer<void>? metadataGate;
  String issuer = testIssuer;
  String sub = 'admin';
  Object? error;
  final List<String> verified = [];
  int metadataCalls = 0;
  @override
  Future<Map<String, dynamic>> metadata(String origin) async {
    metadataCalls++;
    await metadataGate?.future;
    return {
      'issuer': issuer,
      'authorization_endpoint': '$origin/oauth2/authorize',
      'token_endpoint': '$origin/oauth2/token',
      'end_session_endpoint': '$origin/connect/logout',
      'jwks_uri': '$origin/oauth2/jwks',
    };
  }

  @override
  Future<Map<String, dynamic>> userinfo(String origin, String token) async {
    verified.add(token);
    if (error != null) throw error!;
    return {'sub': sub, 'name': 'Arena Administrator'};
  }
}

class SignedInController extends AuthController {
  SignedInController({String origin = testOrigin})
    : super(
        platform: FakeAuthPlatform(),
        storage: MemoryStorage(),
        server: FakeAuthServer(),
        selectedOrigin: () => origin,
      );
  @override
  AuthState build() {
    super.build();
    return AuthState(
      hasSignedIn: true,
      session: AuthSession(
        accessToken: 'existing-session',
        idToken: 'id',
        issuer: testIssuer,
        origin: selectedOrigin()!,
        sub: 'admin',
        name: 'Arena Administrator',
        expiry: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
  }
}
