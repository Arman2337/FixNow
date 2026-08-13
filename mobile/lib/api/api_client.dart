import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

enum ApiMethod { get, post, put, patch, delete }

class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.body,
    this.bearerToken,
    this.headers = const {},
  });

  final ApiMethod method;
  final String path;
  final Map<String, Object?>? body;
  final String? bearerToken;
  final Map<String, String> headers;
}

class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;
}

abstract interface class ApiTransport {
  Future<ApiResponse> send(ApiRequest request);
}

enum ApiFailureKind { offline, timeout, unauthorized, server, invalidResponse }

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.code, this.statusCode});

  final ApiFailureKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($kind, $message)';
}

class ApiClient implements ApiTransport {
  ApiClient({
    required Uri baseUri,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.maxGetAttempts = 2,
    Future<void> Function(Duration)? delay,
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? http.Client(),
       _delay = delay ?? Future<void>.delayed;

  static const _maximumResponseBytes = 1024 * 1024;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Future<void> Function(Duration) _delay;
  final Duration timeout;
  final int maxGetAttempts;

  Future<ApiResponse> uploadFile({
    required String path,
    required String bearerToken,
    required String fieldName,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _baseUri.resolve(path))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $bearerToken'
        ..files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        );
      final response = await _httpClient.send(request).timeout(timeout);
      final responseBytes = await response.stream.toBytes().timeout(timeout);
      final body = _decodeJson(responseBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _safeHttpFailure(response.statusCode, body);
      }
      return ApiResponse(statusCode: response.statusCode, body: body);
    } on TimeoutException {
      throw const ApiException(
        ApiFailureKind.timeout,
        'The request timed out.',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiFailureKind.offline,
        'No network connection.',
      );
    } on FormatException {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The server response was invalid.',
      );
    }
  }

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final attempts = request.method == ApiMethod.get ? maxGetAttempts : 1;
    ApiException? lastFailure;

    for (var attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        return await _sendOnce(request);
      } on ApiException catch (error) {
        lastFailure = error;
        final retryable =
            error.kind == ApiFailureKind.offline ||
            error.kind == ApiFailureKind.timeout ||
            error.kind == ApiFailureKind.server;
        if (!retryable || attempt == attempts) rethrow;
        await _delay(Duration(milliseconds: 200 * attempt));
      }
    }
    throw lastFailure!;
  }

  Future<ApiResponse> _sendOnce(ApiRequest request) async {
    try {
      final uri = _baseUri.resolve(request.path);
      final headers = <String, String>{
        'Accept': 'application/json',
        ...request.headers,
      };
      if (request.bearerToken case final token?) {
        headers['Authorization'] = 'Bearer $token';
      }
      if (request.body != null) {
        headers['Content-Type'] = 'application/json';
      }
      final response = await _httpClient
          .send(
            http.Request(request.method.name.toUpperCase(), uri)
              ..headers.addAll(headers)
              ..body = request.body == null ? '' : jsonEncode(request.body),
          )
          .timeout(timeout);
      final bytes = await response.stream.toBytes().timeout(timeout);
      if (bytes.length > _maximumResponseBytes) {
        throw const ApiException(
          ApiFailureKind.invalidResponse,
          'The server response was too large.',
        );
      }
      final body = _decodeJson(bytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _safeHttpFailure(response.statusCode, body);
      }
      return ApiResponse(statusCode: response.statusCode, body: body);
    } on TimeoutException {
      throw const ApiException(
        ApiFailureKind.timeout,
        'The request timed out.',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiFailureKind.offline,
        'No network connection.',
      );
    } on FormatException {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The server response was invalid.',
      );
    }
  }

  Object? _decodeJson(List<int> bytes) {
    if (bytes.isEmpty) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
      throw const FormatException();
    }
    return decoded;
  }

  ApiException _safeHttpFailure(int status, Object? body) {
    final kind = status == 401
        ? ApiFailureKind.unauthorized
        : status >= 500
        ? ApiFailureKind.server
        : ApiFailureKind.invalidResponse;
    final code = body is Map<String, dynamic> ? body['code'] : null;
    return ApiException(
      kind,
      status >= 500
          ? 'The service is temporarily unavailable.'
          : 'The request could not be completed.',
      code: code is String ? code : null,
      statusCode: status,
    );
  }
}
