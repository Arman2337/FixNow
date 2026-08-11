import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum ApiMethod { get, post, put, patch, delete }

class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.body,
    this.bearerToken,
  });

  final ApiMethod method;
  final String path;
  final Map<String, Object?>? body;
  final String? bearerToken;
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
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.maxGetAttempts = 2,
    Future<void> Function(Duration)? delay,
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? HttpClient(),
       _delay = delay ?? Future<void>.delayed;

  static const _maximumResponseBytes = 1024 * 1024;

  final Uri _baseUri;
  final HttpClient _httpClient;
  final Future<void> Function(Duration) _delay;
  final Duration timeout;
  final int maxGetAttempts;

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
      final ioRequest = await _httpClient
          .openUrl(request.method.name.toUpperCase(), uri)
          .timeout(timeout);
      ioRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (request.bearerToken case final token?) {
        ioRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (request.body case final body?) {
        ioRequest.headers.contentType = ContentType.json;
        ioRequest.write(jsonEncode(body));
      }
      final response = await ioRequest.close().timeout(timeout);
      final bytes = await _readBounded(response).timeout(timeout);
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
    } on SocketException {
      throw const ApiException(
        ApiFailureKind.offline,
        'No network connection.',
      );
    } on HttpException {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The server response was invalid.',
      );
    } on FormatException {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The server response was invalid.',
      );
    }
  }

  Future<Uint8List> _readBounded(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > _maximumResponseBytes) {
        throw const ApiException(
          ApiFailureKind.invalidResponse,
          'The server response was too large.',
        );
      }
    }
    return builder.takeBytes();
  }

  Object? _decodeJson(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
      throw const FormatException();
    }
    return decoded;
  }

  ApiException _safeHttpFailure(int status, Object? body) {
    final kind = status == HttpStatus.unauthorized
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
