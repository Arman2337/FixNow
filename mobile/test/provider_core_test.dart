import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
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
    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('Go online to receive'), findsOneWidget);
    expect(find.textContaining('No active jobs'), findsOneWidget);
    expect(find.textContaining('earnings'), findsNothing);
  });

  testWidgets('verified provider sees an eligible incoming request preview', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: true),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'category-1',
        description: 'Kitchen sink leak',
        createdAt: DateTime.utc(2026, 8, 14),
        version: 1,
        distanceKm: 1.2,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ProviderHomeScreen(controller: controller)),
      ),
    );

    expect(find.text('Incoming requests'), findsOneWidget);
    expect(find.text('Category 1'), findsOneWidget);
    expect(find.text('Kitchen sink leak'), findsOneWidget);
    expect(find.text('About 1.2 km away'), findsOneWidget);
    expect(
      find.text(
        'Customer address and contact details appear only after you accept.',
      ),
      findsOneWidget,
    );
    final localRequestTime = DateTime.utc(2026, 8, 14).toLocal();
    expect(
      find.text(
        'Requested ${localRequestTime.day}/${localRequestTime.month} · '
        '${localRequestTime.hour.toString().padLeft(2, '0')}:'
        '${localRequestTime.minute.toString().padLeft(2, '0')}',
      ),
      findsOneWidget,
    );
    expect(find.text('Accept request'), findsOneWidget);
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
    if (request.path == 'provider-skills/me') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (request.path == 'service-categories') {
      return const ApiResponse(
        statusCode: 200,
        body: {'categories': <Object?>[]},
      );
    }
    if (request.path == 'provider-documents') {
      return const ApiResponse(
        statusCode: 200,
        body: {'documents': <Object?>[]},
      );
    }
    if (request.path.startsWith('bookings?') ||
        request.path.startsWith('bookings/available?')) {
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
