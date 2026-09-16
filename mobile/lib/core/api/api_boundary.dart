import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';

import 'api_error.dart';

/// Install once on the Dio passed to ArenaApi. No logging or retry interceptors.
class ApiBoundaryInterceptor extends Interceptor {
  ApiBoundaryInterceptor({
    required String apiBaseUrl,
    required this.accessToken,
  }) : _base = Uri.parse(apiBaseUrl) {
    if (!_base.hasAuthority ||
        !const {'http', 'https'}.contains(_base.scheme) ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw ArgumentError('apiBaseUrl must be an absolute HTTP(S) base URL.');
    }
  }

  final Uri _base;
  final String? Function() accessToken;

  String get _apiPath => '${_base.path.replaceFirst(RegExp(r'/+$'), '')}/api';

  bool _isApi(Uri target) =>
      target.origin == _base.origin &&
      (target.path == _apiPath || target.path.startsWith('$_apiPath/'));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isApi(options.uri)) {
      final token = accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // Do not forward an attached credential through an unchecked redirect.
      options.followRedirects = false;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final request = response.requestOptions;
    final status = response.statusCode ?? 0;
    final path = request.uri.path;
    if (_isApi(request.uri) &&
        request.method.toUpperCase() == 'GET' &&
        (path == '$_apiPath/events' || path == '$_apiPath/bookings') &&
        status >= 200 &&
        status < 300 &&
        status != 204 &&
        (response.data is! Map || (response.data as Map)['items'] is! List)) {
      handler.reject(
        DioException(
          requestOptions: request,
          response: response,
          error: ApiError(
            'The API returned an invalid page. Please try again.',
          ),
        ),
      );
      return;
    }
    handler.next(response);
  }
}

/// Use the generated APIs directly; map caught errors with describeApiError.
ArenaApi createArenaApi({
  required String apiBaseUrl,
  required String? Function() accessToken,
}) {
  return ArenaApi(
    basePathOverride: apiBaseUrl,
    interceptors: [
      ApiBoundaryInterceptor(apiBaseUrl: apiBaseUrl, accessToken: accessToken),
    ],
  );
}
