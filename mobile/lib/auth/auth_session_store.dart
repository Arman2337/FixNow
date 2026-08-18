import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:html' as html;

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class WebAuthSessionStore implements AuthSessionStore {
  static const _userIdKey = 'fixnow.auth.user_id';
  static const _accessTokenKey = 'fixnow.auth.access_token';
  static const _refreshTokenKey = 'fixnow.auth.refresh_token';
  static const _expiresAtKey = 'fixnow.auth.expires_at';
  static const _verificationEmailKey = 'fixnow.auth.verification_email';
  static const _roleKey = 'fixnow.auth.role';

  @override
  Future<AuthSession?> read() async {
    final storage = html.window.localStorage;
    final userId = storage[_userIdKey];
    final accessToken = storage[_accessTokenKey];
    final refreshToken = storage[_refreshTokenKey];
    final expiresAtStr = storage[_expiresAtKey];
    final roleStr = storage[_roleKey];

    if (userId == null || accessToken == null || refreshToken == null || expiresAtStr == null) {
      await clear();
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) {
      await clear();
      return null;
    }

    return AuthSession(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
      verificationEmail: storage[_verificationEmailKey],
      role: roleStr == 'provider_applicant'
          ? AccountRole.providerApplicant
          : roleStr == 'verified_provider'
              ? AccountRole.verifiedProvider
              : AccountRole.customer,
    );
  }

  @override
  Future<void> write(AuthSession session) async {
    final storage = html.window.localStorage;
    storage[_userIdKey] = session.userId;
    storage[_accessTokenKey] = session.accessToken;
    storage[_refreshTokenKey] = session.refreshToken;
    storage[_expiresAtKey] = session.expiresAt.toUtc().toIso8601String();
    storage[_roleKey] = session.role == AccountRole.customer
        ? 'customer'
        : session.role == AccountRole.providerApplicant
            ? 'provider_applicant'
            : 'verified_provider';
    
    if (session.verificationEmail != null) {
      storage[_verificationEmailKey] = session.verificationEmail!;
    } else {
      storage.remove(_verificationEmailKey);
    }
  }

  @override
  Future<void> clear() async {
    final storage = html.window.localStorage;
    storage.remove(_userIdKey);
    storage.remove(_accessTokenKey);
    storage.remove(_refreshTokenKey);
    storage.remove(_expiresAtKey);
    storage.remove(_verificationEmailKey);
    storage.remove(_roleKey);
  }
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _userIdKey = 'fixnow.auth.user_id';
  static const _accessTokenKey = 'fixnow.auth.access_token';
  static const _refreshTokenKey = 'fixnow.auth.refresh_token';
  static const _expiresAtKey = 'fixnow.auth.expires_at';
  static const _verificationEmailKey = 'fixnow.auth.verification_email';
  static const _roleKey = 'fixnow.auth.role';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
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
    await Future.wait([
      _storage.write(key: _userIdKey, value: session.userId),
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(
        key: _expiresAtKey,
        value: session.expiresAt.toUtc().toIso8601String(),
      ),
      _storage.write(
        key: _roleKey,
        value: session.role == AccountRole.customer
            ? 'customer'
            : session.role == AccountRole.providerApplicant
                ? 'provider_applicant'
                : 'verified_provider',
      ),
      if (session.verificationEmail == null)
        _storage.delete(key: _verificationEmailKey)
      else
        _storage.write(
          key: _verificationEmailKey,
          value: session.verificationEmail,
        ),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
      _storage.delete(key: _verificationEmailKey),
      _storage.delete(key: _roleKey),
    ]);
  }
}
