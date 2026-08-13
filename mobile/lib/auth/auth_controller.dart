import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus {
  initial,
  loading,
  verificationRequired,
  authenticated,
  unauthenticated,
  offline,
  failure,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi api,
    required AuthSessionStore store,
    DateTime Function()? now,
  }) : _api = api,
       _store = store,
       _now = now ?? DateTime.now;

  final AuthApi _api;
  final AuthSessionStore _store;
  final DateTime Function() _now;
  AuthSession? _session;
  Future<AuthSession>? _refreshInFlight;
  String? errorMessage;
  String? verificationEmail;

  AuthStatus status = AuthStatus.initial;
  AuthSession? get session => _session;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  Future<void> restore() async {
    _setStatus(AuthStatus.loading);
    try {
      final stored = await _store.read();
      if (stored == null) {
        _session = null;
        _setStatus(AuthStatus.unauthenticated);
      } else if (stored.isExpired(_now().toUtc())) {
        _session = stored;
        verificationEmail = stored.verificationEmail;
        await _refresh(stored.refreshToken);
      } else {
        _session = stored;
        verificationEmail = stored.verificationEmail;
        _setStatus(
          stored.verificationEmail == null
              ? AuthStatus.authenticated
              : AuthStatus.verificationRequired,
        );
      }
    } on ApiException catch (error) {
      await _handleApiFailure(error);
    } catch (_) {
      _session = null;
      _setStatus(AuthStatus.failure);
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _authenticate(() => _api.login(email: email, password: password));
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    errorMessage = null;
    _setStatus(AuthStatus.loading);
    try {
      final normalizedEmail = email.trim();
      final next = await _api.register(
        email: normalizedEmail,
        password: password,
      );
      await _store.write(next);
      _session = next;
      verificationEmail = next.verificationEmail ?? normalizedEmail;
      try {
        await _api.requestOtp(normalizedEmail);
      } on ApiException {
        errorMessage =
            'Your account was created, but we could not send the code. Try resend.';
      }
      _setStatus(AuthStatus.verificationRequired);
    } on ApiException catch (error) {
      await _handleApiFailure(error);
    } catch (_) {
      _setStatus(AuthStatus.failure);
    }
  }

  Future<void> resendVerification() async {
    final email = verificationEmail;
    if (email == null) return;
    errorMessage = null;
    try {
      await _api.requestOtp(email);
    } on ApiException catch (error) {
      errorMessage = error.statusCode == 429
          ? 'Please wait before requesting another code.'
          : 'We could not send another code. Try again.';
    }
    notifyListeners();
  }

  Future<void> verify(String code) async {
    final email = verificationEmail;
    if (email == null) return;
    errorMessage = null;
    _setStatus(AuthStatus.loading);
    try {
      await _api.verifyOtp(email: email, code: code);
      final current = _session!;
      _session = AuthSession(
        userId: current.userId,
        accessToken: current.accessToken,
        refreshToken: current.refreshToken,
        expiresAt: current.expiresAt,
      );
      await _store.write(_session!);
      verificationEmail = null;
      _setStatus(AuthStatus.authenticated);
    } on ApiException catch (error) {
      errorMessage = error.statusCode == 401
          ? 'That code is incorrect or expired.'
          : 'We could not verify the code. Try again.';
      _setStatus(AuthStatus.verificationRequired);
    }
  }

  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    errorMessage = null;
    _setStatus(AuthStatus.loading);
    try {
      final next = await action();
      await _store.write(next);
      _session = next;
      verificationEmail = next.verificationEmail;
      _setStatus(
        next.verificationEmail == null
            ? AuthStatus.authenticated
            : AuthStatus.verificationRequired,
      );
    } on ApiException catch (error) {
      await _handleApiFailure(error);
    } catch (_) {
      _setStatus(AuthStatus.failure);
    }
  }

  Future<String?> validAccessToken() async {
    final current = _session ?? await _store.read();
    if (current == null) return null;
    if (!current.isExpired(_now().toUtc())) {
      _session = current;
      return current.accessToken;
    }
    try {
      return (await _refresh(current.refreshToken)).accessToken;
    } on ApiException catch (error) {
      await _handleApiFailure(error);
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    try {
      if (refreshToken != null) await _api.logout(refreshToken);
    } on ApiException catch (error) {
      if (error.kind == ApiFailureKind.offline ||
          error.kind == ApiFailureKind.timeout) {
        status = AuthStatus.offline;
      }
    } finally {
      await _store.clear();
      _session = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<AuthSession> _refresh(String refreshToken) {
    final active = _refreshInFlight;
    if (active != null) return active;
    final future = _performRefresh(refreshToken);
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthSession> _performRefresh(String refreshToken) async {
    final refreshed = await _api.refresh(refreshToken);
    final next =
        verificationEmail == null && _session?.verificationEmail == null
        ? refreshed
        : AuthSession(
            userId: refreshed.userId,
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            expiresAt: refreshed.expiresAt,
            verificationEmail: verificationEmail ?? _session?.verificationEmail,
          );
    await _store.write(next);
    _session = next;
    verificationEmail = next.verificationEmail;
    _setStatus(
      next.verificationEmail == null
          ? AuthStatus.authenticated
          : AuthStatus.verificationRequired,
    );
    return next;
  }

  Future<void> _handleApiFailure(ApiException error) async {
    errorMessage = switch (error.statusCode) {
      401 => 'Email or password is incorrect.',
      409 => 'An account already exists for this email.',
      _ when error.kind == ApiFailureKind.offline =>
        'You appear to be offline.',
      _ when error.kind == ApiFailureKind.timeout =>
        'The request timed out. Try again.',
      _ => 'We could not complete that request. Try again.',
    };
    if (error.kind == ApiFailureKind.unauthorized) {
      await _store.clear();
      _session = null;
      _setStatus(AuthStatus.unauthenticated);
    } else if (error.kind == ApiFailureKind.offline ||
        error.kind == ApiFailureKind.timeout) {
      _setStatus(AuthStatus.offline);
    } else {
      _setStatus(AuthStatus.failure);
    }
  }

  void _setStatus(AuthStatus next) {
    status = next;
    notifyListeners();
  }
}
