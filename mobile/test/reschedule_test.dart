import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_reschedule_sheet.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  final sampleBooking = CustomerBooking(
    id: 'booking-resched-1',
    serviceCategoryId: 'cat-electrical',
    status: 'ASSIGNED',
    description: 'Switchboard sparking in kitchen.',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    version: 2,
    scheduledAt: DateTime.now().add(const Duration(hours: 3)),
  );

  group('BookingRepository reschedule', () {
    test('calls reschedule API endpoint and parses response', () async {
      final fakeTransport = _FakeTransport();
      final repository = BookingRepository(
        api: fakeTransport,
        accessToken: () async => 'test-token',
      );

      final newTime = DateTime(2026, 8, 30, 14, 0);
      final updated = await repository.reschedule(
        booking: sampleBooking,
        newScheduledAt: newTime,
        reason: 'Client requested afternoon visit',
      );

      expect(fakeTransport.lastRequest?.path, 'bookings/booking-resched-1/reschedule');
      expect(fakeTransport.lastBody?['newScheduledAt'], newTime.toUtc().toIso8601String());
      expect(fakeTransport.lastBody?['expectedVersion'], 2);
      expect(fakeTransport.lastBody?['reason'], 'Client requested afternoon visit');
      expect(updated.id, 'booking-resched-1');
      expect(updated.scheduledAt, isNotNull);
    });
  });

  group('BookingDetailScreen reschedule integration', () {
    testWidgets('displays scheduled badge and reschedule button for ASSIGNED booking',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool rescheduleTapped = false;

      await tester.pumpWidget(
        host(
          BookingDetailScreen(
            booking: sampleBooking,
            onReschedule: () => rescheduleTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Scheduled for:'), findsOneWidget);
      expect(find.widgetWithText(FixButton, 'Reschedule booking'), findsOneWidget);

      await tester.tap(find.widgetWithText(FixButton, 'Reschedule booking'));
      await tester.pumpAndSettle();

      expect(rescheduleTapped, isTrue);
    });

    testWidgets('hides reschedule button for COMPLETED booking', (tester) async {
      final completed = sampleBooking.copyWith(status: 'COMPLETED');

      await tester.pumpWidget(
        host(
          BookingDetailScreen(
            booking: completed,
            onReschedule: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FixButton, 'Reschedule booking'), findsNothing);
    });
  });

  group('FixRescheduleSheet widget', () {
    testWidgets('allows picking new arrival window and confirming reschedule',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeTransport = _FakeTransport();
      final repository = BookingRepository(
        api: fakeTransport,
        accessToken: () async => 'test-token',
      );
      final controller = BookingController(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FixRescheduleSheet.show(
                    context,
                    booking: sampleBooking,
                    controller: controller,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Reschedule Service'), findsOneWidget);
      expect(find.text('Reason for Rescheduling'), findsOneWidget);
      expect(find.text('Confirm New Arrival Time'), findsOneWidget);

      // Tap Confirm New Arrival Time
      await tester.tap(find.text('Confirm New Arrival Time'));
      await tester.pumpAndSettle();

      expect(fakeTransport.lastRequest?.path, 'bookings/booking-resched-1/reschedule');
    });
  });
}

class _FakeTransport implements ApiTransport {
  ApiRequest? lastRequest;
  Map<String, dynamic>? lastBody;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    lastRequest = request;
    if (request.body is Map<String, dynamic>) {
      lastBody = request.body as Map<String, dynamic>;
    }
    return ApiResponse(
      statusCode: 200,
      body: {
        'booking': {
          'id': 'booking-resched-1',
          'serviceCategoryId': 'cat-electrical',
          'status': 'ASSIGNED',
          'description': 'Switchboard sparking in kitchen.',
          'locationLat': 12.9716,
          'locationLng': 77.5946,
          'createdAt': '2026-08-28T00:00:00.000Z',
          'scheduledAt': lastBody?['newScheduledAt'] ?? '2026-08-30T14:00:00.000Z',
          'version': 3,
        }
      },
    );
  }
}
