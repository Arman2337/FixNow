import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 11, 12);

  test('restores an authenticated session without refreshing', () async {
    final store = MemorySessionStore(
      session: _session(now.add(const Duration(hours: 1))),
    );
    final transport = FakeTransport();
    final controller = AuthController(
      api: AuthApi(transport),
      store: store,
      now: () => now,
    );

    await controller.restore();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.session?.accessToken, 'access');
    expect(transport.requests, isEmpty);
  });

  test('refreshes an expired session and persists rotated tokens', () async {
    final store = MemorySessionStore(
      session: _session(now.subtract(const Duration(minutes: 1))),
    );
    final transport = FakeTransport(
      responses: [
        _tokenResponse(access: 'next-access', refresh: 'next-refresh'),
      ],
    );
    final controller = AuthController(
      api: AuthApi(transport),
      store: store,
      now: () => now,
    );

    await controller.restore();

    expect(controller.status, AuthStatus.authenticated);
    expect(store.session?.accessToken, 'next-access');
    expect(transport.requests.single.path, 'auth/token/refresh');
    expect(transport.requests.single.body?['refreshToken'], 'refresh');
  });

  test(
    'reports offline state while retaining a stored session for retry',
    () async {
      final stored = _session(now.subtract(const Duration(minutes: 1)));
      final store = MemorySessionStore(session: stored);
      final transport = FakeTransport(
        error: const ApiException(
          ApiFailureKind.offline,
          'No network connection.',
        ),
      );
      final controller = AuthController(
        api: AuthApi(transport),
        store: store,
        now: () => now,
      );

      await controller.restore();

      expect(controller.status, AuthStatus.offline);
      expect(store.session, same(stored));
    },
  );

  test('login can be retried after an offline failure', () async {
    final store = MemorySessionStore();
    final transport = FakeTransport(
      error: const ApiException(
        ApiFailureKind.offline,
        'No network connection.',
      ),
    );
    final controller = AuthController(
      api: AuthApi(transport),
      store: store,
      now: () => now,
    );

    await controller.login(email: 'person@example.com', password: 'secret');
    expect(controller.status, AuthStatus.offline);

    transport
      ..error = null
      ..responses.add(_tokenResponse());
    await controller.login(email: 'person@example.com', password: 'secret');

    expect(controller.status, AuthStatus.authenticated);
    expect(store.session, isNotNull);
    expect(transport.requests, hasLength(2));
  });

  test('register creates and persists a customer session', () async {
    final store = MemorySessionStore();
    final transport = FakeTransport(
      responses: [
        _tokenResponse(),
        const ApiResponse(statusCode: 202, body: {'accepted': true}),
      ],
    );
    final controller = AuthController(
      api: AuthApi(transport),
      store: store,
      now: () => now,
    );

    await controller.register(
      email: ' new@example.com ',
      password: 'long-password',
    );

    expect(controller.status, AuthStatus.verificationRequired);
    expect(store.session?.accessToken, 'access');
    expect(transport.requests.first.path, 'auth/customer/register');
    expect(transport.requests.first.body?['email'], 'new@example.com');
    expect(transport.requests.last.path, 'auth/otp/request');
  });

  test(
    'provider registration uses provider endpoint and persists role',
    () async {
      final store = MemorySessionStore();
      final transport = FakeTransport(
        responses: [
          _tokenResponse(role: 'provider_applicant'),
          const ApiResponse(statusCode: 202, body: {'accepted': true}),
        ],
      );
      final controller = AuthController(
        api: AuthApi(transport),
        store: store,
        now: () => now,
      );

      await controller.register(
        email: 'provider@example.com',
        password: 'long-password',
        role: AccountRole.providerApplicant,
      );

      expect(transport.requests.first.path, 'auth/provider/register');
      expect(store.session?.role, AccountRole.providerApplicant);
      expect(controller.status, AuthStatus.verificationRequired);
    },
  );

  test(
    'logout clears local session even when the network is offline',
    () async {
      final store = MemorySessionStore(
        session: _session(now.add(const Duration(hours: 1))),
      );
      final transport = FakeTransport(
        error: const ApiException(
          ApiFailureKind.offline,
          'No network connection.',
        ),
      );
      final controller = AuthController(
        api: AuthApi(transport),
        store: store,
        now: () => now,
      );
      await controller.restore();

      await controller.logout();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.session, isNull);
      expect(store.session, isNull);
      expect(transport.requests.last.path, 'auth/logout');
    },
  );

  test('restore without a stored session remains signed out', () async {
    final controller = AuthController(
      api: AuthApi(FakeTransport()),
      store: MemorySessionStore(),
      now: () => now,
    );

    await controller.restore();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.session, isNull);
  });

  test('an unauthorized refresh clears the stored session', () async {
    final store = MemorySessionStore(
      session: _session(now.subtract(const Duration(minutes: 1))),
    );
    final controller = AuthController(
      api: AuthApi(
        FakeTransport(
          error: const ApiException(
            ApiFailureKind.unauthorized,
            'Unauthorized.',
          ),
        ),
      ),
      store: store,
      now: () => now,
    );

    await controller.restore();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
  });

  test('validAccessToken returns a current stored token', () async {
    final controller = AuthController(
      api: AuthApi(FakeTransport()),
      store: MemorySessionStore(
        session: _session(now.add(const Duration(hours: 1))),
      ),
      now: () => now,
    );

    expect(await controller.validAccessToken(), 'access');
  });

  test('rejects malformed authentication responses', () async {
    final transport = FakeTransport(
      responses: [
        const ApiResponse(statusCode: 200, body: {'userId': 'user-1'}),
      ],
    );
    final controller = AuthController(
      api: AuthApi(transport),
      store: MemorySessionStore(),
      now: () => now,
    );

    await controller.login(email: ' person@example.com ', password: 'secret');

    expect(controller.status, AuthStatus.failure);
    expect(transport.requests.single.body?['email'], 'person@example.com');
  });
}

AuthSession _session(DateTime expiresAt) => AuthSession(
  userId: 'user-1',
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: expiresAt,
);

ApiResponse _tokenResponse({
  String access = 'access',
  String refresh = 'refresh',
  String role = 'customer',
}) => ApiResponse(
  statusCode: 200,
  body: {
    'userId': 'user-1',
    'role': role,
    'accessToken': access,
    'refreshToken': refresh,
    'tokenType': 'Bearer',
    'expiresIn': 3600,
  },
);

class MemorySessionStore implements AuthSessionStore {
  MemorySessionStore({this.session});
  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;
}

class FakeTransport implements ApiTransport {
  FakeTransport({List<ApiResponse>? responses, this.error})
    : responses = responses ?? [];

  final List<ApiRequest> requests = [];
  final List<ApiResponse> responses;
  ApiException? error;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (error case final failure?) throw failure;
    return responses.removeAt(0);
  }
}
