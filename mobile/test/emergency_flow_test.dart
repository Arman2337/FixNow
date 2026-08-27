import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/emergency/emergency_confirm_screen.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_idle.dart';

class FakeTransport implements ApiTransport {
  FakeTransport(this.postResponse, this.getStatus);

  final ApiResponse postResponse;
  final ApiResponse Function() getStatus;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.method == ApiMethod.post) return postResponse;
    return getStatus();
  }
}

class FixedLocation implements BookingLocationProvider {
  @override
  Future<BookingLocationFix> resolve() async => BookingLocationFix(
        latitude: 23.02,
        longitude: 72.57,
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      );
}

const category = ServiceCategory(
  id: '11111111-2222-4333-8444-555555555555',
  name: 'Emergency plumbing',
  slug: 'emergency-plumbing',
  description: 'Major leaks and flooding',
  isEmergency: true,
);

Future<EmergencyConfirmScreen> screen(ApiTransport transport) async =>
    EmergencyConfirmScreen(
      categories: const [category],
      repository: EmergencyRepository(transport),
      locationProvider: FixedLocation(),
    );

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        // Generous fixed height so every field and the confirm button are
        // built and hittable without scrolling in tests.
        body: SizedBox(height: 2600, child: child),
      ),
    );

/// Confirms via the button's tap path. pumpIdle() declares reduce-motion
/// suite-wide (FakeAccessibilityFeatures), and HoldToConfirmButton swaps its
/// long-press hold for a plain tap in that mode — so a tap here is what a
/// reduced-motion user actually does. Hold-gesture mechanics are covered in
/// signature_motion_test.dart.
Future<void> confirmAlert(WidgetTester tester) async {
  await tester.tap(find.byType(HoldToConfirmButton));
  await tester.pump();
}

void main() {
  final created = {
    'bookingId': 'e1000000-0000-4000-8000-000000000001',
    'status': 'REQUESTED',
    'currentWave': 1,
    'fallbackRequired': false,
    'guidance': null,
    'eligibleCount': 7,
  };
  final okStatus = {
    'bookingId': 'e1000000-0000-4000-8000-000000000001',
    'status': 'REQUESTED',
    'currentWave': 1,
    'fallbackRequired': false,
    'guidance': null,
  };

  testWidgets('shows the mandatory public-emergency notice before anything',
      (tester) async {
    final transport = FakeTransport(
      ApiResponse(statusCode: 201, body: created),
      () => ApiResponse(statusCode: 200, body: okStatus),
    );
    await tester.pumpWidget(host(await screen(transport)));

    expect(find.textContaining('It is not an emergency service'), findsOneWidget);
    expect(find.textContaining('local emergency number first'), findsOneWidget);
  });

  testWidgets('confirm posts once with idempotency key and shows wave progress',
      (tester) async {
    final transport = FakeTransport(
      ApiResponse(statusCode: 201, body: created),
      () => ApiResponse(statusCode: 200, body: okStatus),
    );
    await tester.pumpWidget(host(await screen(transport)));
    await tester.pumpIdle();

    await tester.ensureVisible(find.text('Send emergency alert'));
    await tester.pumpIdle();
    await tester.enterText(find.byType(TextField), 'Water everywhere');
    await tester.pump();
    await tester.pump(); // let the onChanged rebuild enable the button
    await confirmAlert(tester);
    await tester.pumpIdle();
    await tester.pumpIdle();

    final post = transport.requests.firstWhere((r) => r.method == ApiMethod.post);
    expect(post.path, 'emergency/requests');
    expect(post.headers['Idempotency-Key'], startsWith('emergency-'));
    expect(post.body!['serviceCategoryId'], category.id);
    expect(post.body!['locationLat'], 23.02);
    expect(find.textContaining('wave 1'), findsOneWidget);
    expect(find.text('Alert sent'), findsOneWidget);
  });

  testWidgets('renders the honest fallback guidance at wave 3', (tester) async {
    final fallbackStatus = {
      ...okStatus,
      'currentWave': 3,
      'fallbackRequired': true,
      'guidance':
          'No professional is available right now. If this is dangerous, call your local emergency services.',
    };
    final transport = FakeTransport(
      ApiResponse(statusCode: 201, body: created),
      () => ApiResponse(statusCode: 200, body: fallbackStatus),
    );
    await tester.pumpWidget(host(await screen(transport)));
    await tester.pumpIdle();
    await tester.ensureVisible(find.text('Send emergency alert'));
    await tester.pumpIdle();
    await tester.enterText(find.byType(TextField), 'Gas smell');
    await tester.pump();
    await confirmAlert(tester);
    await tester.pumpIdle();
    await tester.pumpIdle();

    expect(
      find.textContaining('No professional is available right now'),
      findsOneWidget,
    );
  });

  testWidgets('a failed alert keeps the form with actionable copy', (tester) async {
    final transport = FakeTransport(
      const ApiResponse(statusCode: 500, body: <Object?>{}),
      () => ApiResponse(statusCode: 200, body: okStatus),
    );
    await tester.pumpWidget(host(await screen(transport)));
    await tester.pumpIdle();
    await tester.ensureVisible(find.text('Send emergency alert'));
    await tester.pumpIdle();
    await tester.enterText(find.byType(TextField), 'Sparks from socket');
    await tester.pump();
    await confirmAlert(tester);
    await tester.pumpIdle();
    await tester.pumpIdle();

    expect(
        find.text('Hold to send emergency alert'), findsOneWidget); // form still here
    expect(find.textContaining('could not be sent'), findsOneWidget);
    expect(find.textContaining('call your local emergency services'),
        findsOneWidget);
  });
}
