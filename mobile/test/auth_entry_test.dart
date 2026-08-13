import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/app/app.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('welcome and role selection lead to customer registration', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Trusted help.\nWhen you need it.'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('I want to join as'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Service provider'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
  });

  testWidgets('provider selection uses honest professional onboarding copy', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service provider'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('SERVICE PROVIDER'), findsOneWidget);
    expect(find.textContaining('Verification is required'), findsOneWidget);
  });

  testWidgets('sign in intent does not claim unsupported recovery', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('Forgot password'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('provider session routes to incomplete onboarding handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        session: AuthSession(
          userId: 'provider-1',
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          role: AccountRole.providerApplicant,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile incomplete'), findsOneWidget);
    expect(find.textContaining('cannot receive jobs yet'), findsOneWidget);
  });

  testWidgets('auth entry remains usable on a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Get started'), findsOneWidget);
  });
}

FixNowApp _app({AuthSession? session}) => FixNowApp(
  environment: AppEnvironment.production,
  apiTransport: _Transport(),
  sessionStore: _Store(session),
  locationGateway: _LocationGateway(),
);

class _Store implements AuthSessionStore {
  _Store(this.session);
  AuthSession? session;

  @override
  Future<void> clear() async => session = null;
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession value) async => session = value;
}

class _Transport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: <Object?>[]);
}

class _LocationGateway implements LocationPermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;
  @override
  Future<bool> openSettings() async => false;
  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;
}
