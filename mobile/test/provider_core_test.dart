import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'provider applicant sees truthful incomplete verification state',
    (tester) async {
      final controller = ProviderController(
        ProviderRepository(
          api: _ProviderTransport(verified: false),
          accessToken: () async => 'token',
        ),
      );
      await controller.load(verified: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProviderOnboardingScreen(
            controller: controller,
            onSignOut: () {},
          ),
        ),
      );
      expect(find.text('Profile incomplete'), findsOneWidget);
      expect(find.text('Identity documents'), findsOneWidget);
      expect(find.textContaining('never shown publicly'), findsOneWidget);
    },
  );

  testWidgets('verified provider sees availability without fake work', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: true),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ProviderHomeScreen(controller: controller)),
      ),
    );
    expect(find.text('Offline'), findsWidgets);
    expect(find.text('Go online'), findsOneWidget);
    expect(find.textContaining('No active assigned jobs'), findsOneWidget);
    expect(find.textContaining('earnings'), findsNothing);
  });
}

class _ProviderTransport implements ApiTransport {
  _ProviderTransport({required this.verified});
  final bool verified;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == 'provider-applications/me') {
      return ApiResponse(
        statusCode: 200,
        body: {
          'status': verified ? 'approved' : 'unverified',
          'decisionReason': null,
        },
      );
    }
    if (request.path == 'provider-profile/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'displayName': 'Amina Services',
          'bio': 'Licensed professional',
          'serviceRadiusKm': 15,
          'baseLatitude': 25.2,
          'baseLongitude': 55.3,
        },
      );
    }
    if (request.path == 'provider-availability/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {'status': 'offline', 'version': 2},
      );
    }
    if (request.path.startsWith('bookings?')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    throw const ApiException(
      ApiFailureKind.invalidResponse,
      'Unexpected request',
    );
  }
}
