import 'dart:convert';

import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'fixnow.auth.session';
  static const _userIdKey = 'fixnow.auth.user_id';
  static const _accessTokenKey = 'fixnow.auth.access_token';
  static const _refreshTokenKey = 'fixnow.auth.refresh_token';
  static const _expiresAtKey = 'fixnow.auth.expires_at';
  static const _verificationEmailKey = 'fixnow.auth.verification_email';
  static const _roleKey = 'fixnow.auth.role';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null) {
      try {
        final data = jsonDecode(encoded) as Map<String, dynamic>;
        return AuthSession(
          userId: data['userId'] as String,
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          expiresAt: DateTime.parse(data['expiresAt'] as String).toUtc(),
          verificationEmail: data['verificationEmail'] as String?,
          role: AccountRole.values.byName(data['role'] as String),
        );
      } on Object {
        await clear();
        return null;
      }
    }
    final values = await Future.wait([
      _storage.read(key: _userIdKey),
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _expiresAtKey),
      _storage.read(key: _verificationEmailKey),
      _storage.read(key: _roleKey),
    ]);
    if (values.take(4).any((value) => value == null)) {
      await clear();
      return null;
    }
    final expiresAt = DateTime.tryParse(values[3]!);
    if (expiresAt == null) {
      await clear();
      return null;
    }
    return AuthSession(
      userId: values[0]!,
      accessToken: values[1]!,
      refreshToken: values[2]!,
      expiresAt: expiresAt.toUtc(),
      verificationEmail: values[4],
      role: values[5] == 'provider_applicant'
          ? AccountRole.providerApplicant
          : values[5] == 'verified_provider'
          ? AccountRole.verifiedProvider
          : AccountRole.customer,
    );
  }

  @override
  Future<void> write(AuthSession session) async {
    // One encrypted write also initializes the browser encryption key once.
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'userId': session.userId,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'expiresAt': session.expiresAt.toUtc().toIso8601String(),
        'role': session.role.name,
        'verificationEmail': session.verificationEmail,
      }),
    );
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _sessionKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
      _storage.delete(key: _verificationEmailKey),
      _storage.delete(key: _roleKey),
    ]);
  }
}

/// Uses the package's supported browser storage implementation on Flutter web.
/// This avoids importing browser-only Dart libraries into native and test builds.
class WebAuthSessionStore extends SecureAuthSessionStore {
  WebAuthSessionStore({super.storage});
}
