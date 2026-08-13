import 'dart:convert';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';

class AuthApi {
  AuthApi(this._transport, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiTransport _transport;
  final DateTime Function() _now;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/customer/login',
        body: {'email': email.trim(), 'password': password},
      ),
    );
    return _parseSession(response.body, verificationEmail: email.trim());
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/customer/register',
        body: {'email': email.trim(), 'password': password},
      ),
    );
    return _parseSession(response.body, verificationEmail: email.trim());
  }

  Future<void> requestOtp(String email) async {
    await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/otp/request',
        body: {'email': email.trim()},
      ),
    );
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/otp/verify',
        body: {'email': email.trim(), 'code': code.trim()},
      ),
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/token/refresh',
        body: {'refreshToken': refreshToken},
      ),
    );
    return _parseSession(response.body);
  }

  Future<void> logout(String refreshToken) async {
    await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'auth/logout',
        body: {'refreshToken': refreshToken},
      ),
    );
  }

  AuthSession _parseSession(Object? rawBody, {String? verificationEmail}) {
    final body = rawBody is Map<String, dynamic> ? rawBody : null;
    final userId = body?['userId'];
    final accessToken = body?['accessToken'];
    final refreshToken = body?['refreshToken'];
    final expiresIn = body?['expiresIn'];
    if (userId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num ||
        expiresIn <= 0) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The authentication response was invalid.',
      );
    }
    return AuthSession(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: _now().toUtc().add(Duration(seconds: expiresIn.toInt())),
      verificationEmail: _isPending(accessToken) ? verificationEmail : null,
    );
  }

  bool _isPending(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, dynamic> &&
          payload['accountStatus'] == 'pending_verification';
    } catch (_) {
      return false;
    }
  }
}
