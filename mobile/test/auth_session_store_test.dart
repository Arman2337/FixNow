import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a saved provider session survives creating a fresh store', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = AuthSession(
      userId: 'provider-1',
      accessToken: 'synthetic-access',
      refreshToken: 'synthetic-refresh',
      expiresAt: DateTime.utc(2026, 12, 1),
      role: AccountRole.providerApplicant,
    );
    await SecureAuthSessionStore().write(session);
    final restored = await SecureAuthSessionStore().read();
    expect(restored?.userId, session.userId);
    expect(restored?.role, AccountRole.providerApplicant);
    expect(restored?.refreshToken, session.refreshToken);
    await SecureAuthSessionStore().clear();
    expect(await SecureAuthSessionStore().read(), isNull);
  });

  test('legacy encrypted fields remain readable and can be upgraded', () async {
    FlutterSecureStorage.setMockInitialValues({
      'fixnow.auth.user_id': 'legacy-customer',
      'fixnow.auth.access_token': 'synthetic-access',
      'fixnow.auth.refresh_token': 'synthetic-refresh',
      'fixnow.auth.expires_at': '2026-12-01T00:00:00Z',
      'fixnow.auth.role': 'customer',
    });
    final store = SecureAuthSessionStore();
    final legacy = await store.read();
    expect(legacy?.userId, 'legacy-customer');
    await store.write(legacy!);
    expect((await SecureAuthSessionStore().read())?.userId, 'legacy-customer');
    await store.clear();
    expect(await SecureAuthSessionStore().read(), isNull);
  });
}
