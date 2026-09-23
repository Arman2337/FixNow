import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServiceRequestScreen acceptance routing', () {
    testWidgets(
      'auto-pops with CustomerBooking when provider accepts during radar animation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeTransport = _FakeTransport();
        final repository = BookingRepository(
          api: fakeTransport,
          accessToken: () async => 'test-token',
        );
        final controller = BookingController(repository);

        const category = ServiceCategory(
          id: 'cat-plumbing',
          name: 'Plumbing',
          slug: 'plumbing',
        );

        dynamic poppedResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    poppedResult = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestScreen(
                          category: category,
                          controller: controller,
                          initialDescription: 'Leaking pipe under kitchen sink.',
                          locationProvider: _FixedLocation(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Request'),
                ),
              ),
            ),
          ),
        );

        // Open the screen
        await tester.tap(find.text('Open Request'));
        await tester.pumpAndSettle();

        // Submit the request
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find a verified provider'));
        await tester.pump(); // starts submit
        await tester.pump(const Duration(milliseconds: 100));

        // Radar view is now showing
        expect(find.byType(MatchRadarView), findsOneWidget);
        expect(find.text('Sharing your request…'), findsOneWidget);

        // Provider accepts the booking in backend / controller:
        final currentBooking = controller.bookings.first;
        final accepted = CustomerBooking(
          id: currentBooking.id,
          serviceCategoryId: currentBooking.serviceCategoryId,
          status: 'ASSIGNED',
          description: currentBooking.description,
          createdAt: currentBooking.createdAt,
          version: currentBooking.version + 1,
          locationLatitude: currentBooking.locationLatitude,
          locationLongitude: currentBooking.locationLongitude,
        );
        controller.bookings = [accepted];
        controller.notifyListeners();

        // Pump frame to let listener detect ASSIGNED status
        await tester.pumpAndSettle();

        // Screen has popped! Radar view is gone.
        expect(find.byType(MatchRadarView), findsNothing);
        expect(poppedResult, isA<CustomerBooking>());
        expect((poppedResult as CustomerBooking).status, 'ASSIGNED');
        expect((poppedResult as CustomerBooking).id, currentBooking.id);
      },
    );

    testWidgets(
      'Skip button on MatchRadarView returns CustomerBooking if already accepted',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeTransport = _FakeTransport();
        final repository = BookingRepository(
          api: fakeTransport,
          accessToken: () async => 'test-token',
        );
        final controller = BookingController(repository);

        const category = ServiceCategory(
          id: 'cat-plumbing',
          name: 'Plumbing',
          slug: 'plumbing',
        );

        dynamic poppedResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    poppedResult = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestScreen(
                          category: category,
                          controller: controller,
                          initialDescription: 'Fix leaking pipe.',
                          locationProvider: _FixedLocation(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Request'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Request'));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find a verified provider'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MatchRadarView), findsOneWidget);

        // Simulate that the provider accepted
        final current = controller.bookings.first;
        controller.bookings = [
          CustomerBooking(
            id: current.id,
            serviceCategoryId: current.serviceCategoryId,
            status: 'ASSIGNED',
            description: current.description,
            createdAt: current.createdAt,
            version: 2,
            locationLatitude: current.locationLatitude,
            locationLongitude: current.locationLongitude,
          ),
        ];

        // Tap Skip
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.byType(MatchRadarView), findsNothing);
        expect(poppedResult, isA<CustomerBooking>());
        expect((poppedResult as CustomerBooking).status, 'ASSIGNED');
      },
    );
  });
}

class _FixedLocation implements BookingLocationProvider {
  @override
  Future<BookingLocationFix> resolve() async => BookingLocationFix(
    latitude: 17.3850,
    longitude: 78.4867,
    accuracyMeters: 5.0,
    timestamp: DateTime.now(),
  );
}

class _FakeTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(
      statusCode: 201,
      body: {
        'booking': {
          'id': 'booking-accept-123',
          'serviceCategoryId': 'cat-plumbing',
          'status': 'REQUESTED',
          'description': 'Leaking pipe under kitchen sink.',
          'createdAt': '2026-09-18T10:00:00.000Z',
          'version': 1,
          'locationLat': 17.385,
          'locationLng': 78.4867,
        },
      },
    );
  }
}
