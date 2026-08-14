import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/auth/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the fixed code only when local bypass UI is enabled', (
    tester,
  ) async {
    final controller = AuthController(
      api: AuthApi(_VerificationTransport()),
      store: _MemorySessionStore(),
    );
    await controller.register(
      email: 'temporary@example.com',
      password: 'long-password',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VerificationScreen(
          controller: controller,
          localOtpBypassEnabled: true,
        ),
      ),
    );
    expect(find.text('Local testing: use 000000.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: VerificationScreen(
          controller: controller,
          localOtpBypassEnabled: false,
        ),
      ),
    );
    expect(find.text('Local testing: use 000000.'), findsNothing);
  });
}

class _MemorySessionStore implements AuthSessionStore {
  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;
}

class _VerificationTransport implements ApiTransport {
  var requestCount = 0;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requestCount += 1;
    if (requestCount == 1) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'userId': 'user-1',
          'role': 'customer',
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
        },
      );
    }
    return const ApiResponse(statusCode: 202, body: {'accepted': true});
  }
}
