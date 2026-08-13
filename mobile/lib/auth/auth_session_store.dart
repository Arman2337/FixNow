import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class MemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;
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
            : 'provider_applicant',
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
