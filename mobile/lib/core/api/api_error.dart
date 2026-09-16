import 'dart:convert';

import 'package:dio/dio.dart';

/// Presentation-safe error data. Never retains requests, tokens, or raw causes.
class ApiError implements Exception {
  ApiError(this.message, {Map<String, String> fields = const {}})
    : fields = Map.unmodifiable(fields);

  final String message;
  final Map<String, String> fields;

  @override
  String toString() => message;
}

/// Mirrors the web client's describeApiError policy.
ApiError describeApiError(Object? error) {
  if (error is ApiError) return error;
  if (error is! DioException) {
    return ApiError('Something went wrong. Please try again.');
  }
  if (error.error is ApiError) return error.error as ApiError;
  final status = error.response?.statusCode;
  if (status == null &&
      const {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type)) {
    return ApiError(
      'We could not reach the API. Check your connection and try again.',
    );
  }
  if (status == 401) {
    return ApiError('Your session has expired. Sign in again to continue.');
  }
  if (status == 403) {
    return ApiError(
      'Your account does not have permission to perform this action.',
    );
  }
  if (status == 404) {
    return ApiError(
      'This record could not be found. It may have been removed.',
    );
  }
  if (status != null && status >= 500) {
    return ApiError(
      'The server could not complete this request. Please try again.',
    );
  }
  if (status == null || status < 400) {
    return ApiError('Something went wrong. Please try again.');
  }

  Object? body = error.response?.data;
  if (body is String) {
    try {
      body = jsonDecode(body);
    } on FormatException {
      body = null;
    }
  }
  final fields = <String, String>{};
  // Generated ProblemDetail discards the API's top-level `errors` extension.
  // Read it here before attempting generated model deserialization.
  if (body is Map && body['errors'] is List) {
    for (final violation in body['errors'] as List) {
      if (violation is Map &&
          violation['field'] is String &&
          violation['message'] is String) {
        fields[violation['field'] as String] = violation['message'] as String;
      }
    }
  }
  return ApiError(
    body is Map && body['detail'] is String
        ? body['detail'] as String
        : 'The request could not be completed. Check your input and try again.',
    fields: fields,
  );
}
