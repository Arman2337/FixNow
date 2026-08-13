import 'package:fixnow_mobile/app/app.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the customer shell with design tokens', (tester) async {
    await tester.pumpWidget(_testApp(AppEnvironment.development));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, AppColors.primary);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.background);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('navigates between shell destinations', (tester) async {
    await tester.pumpWidget(_testApp(AppEnvironment.development));

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('No active booking'), findsOneWidget);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);
  });

  testWidgets('help uses customer-safe preview language', (tester) async {
    await tester.pumpWidget(_testApp(AppEnvironment.development));

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tracked product task'), findsNothing);
    expect(
      find.textContaining('contact local emergency services'),
      findsOneWidget,
    );
  });

  testWidgets('supports narrow screens and enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _testApp(AppEnvironment.development),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the debug banner in production', (tester) async {
    await tester.pumpWidget(_testApp(AppEnvironment.production));

    expect(find.byType(Banner), findsNothing);
  });
}

FixNowApp _testApp(AppEnvironment environment) => FixNowApp(
  environment: environment,
  apiTransport: _TestTransport(),
  sessionStore: _EmptySessionStore(),
  locationGateway: _DeniedLocationGateway(),
);

class _TestTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == 'service-categories/active') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    throw const ApiException(ApiFailureKind.unauthorized, 'Sign in required.');
  }
}

class _EmptySessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession session) async {}
}

class _DeniedLocationGateway implements LocationPermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;
}
