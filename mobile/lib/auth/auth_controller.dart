import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus {
  initial,
  loading,
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
        await _refresh(stored.refreshToken);
      } else {
        _session = stored;
        _setStatus(AuthStatus.authenticated);
      }
    } on ApiException catch (error) {
      await _handleApiFailure(error);
    } catch (_) {
      _session = null;
      _setStatus(AuthStatus.failure);
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setStatus(AuthStatus.loading);
    try {
      final next = await _api.login(email: email, password: password);
      await _store.write(next);
      _session = next;
      _setStatus(AuthStatus.authenticated);
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
    final next = await _api.refresh(refreshToken);
    await _store.write(next);
    _session = next;
    _setStatus(AuthStatus.authenticated);
    return next;
  }

  Future<void> _handleApiFailure(ApiException error) async {
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
