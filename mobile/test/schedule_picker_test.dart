import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_schedule_picker.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/booking_schedule.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('BookingSchedule model', () {
    test('computes targetScheduledAt and formatted summaries accurately', () {
      final baseDate = DateTime(2026, 8, 29);
      final scheduleNow = BookingSchedule(
        mode: ScheduleMode.now,
        date: baseDate,
        slot: TimeSlot.standardSlots[0],
      );

      expect(scheduleNow.isNow, isTrue);
      expect(scheduleNow.targetScheduledAt, isNull);
      expect(scheduleNow.formattedSummary, contains('Immediate arrival'));

      final scheduleLater = BookingSchedule(
        mode: ScheduleMode.later,
        date: baseDate,
        slot: TimeSlot.standardSlots[1], // 12:00 PM - 03:00 PM (hour 12)
      );

      expect(scheduleLater.isNow, isFalse);
      expect(scheduleLater.targetScheduledAt, DateTime(2026, 8, 29, 12, 0));
      expect(scheduleLater.formattedSummary, contains('12:00 PM – 03:00 PM'));

      final upcoming = BookingSchedule.getUpcomingDates(baseDate);
      expect(upcoming.length, 7);
      expect(upcoming.first.day, 29);
    });
  });

  group('FixSchedulePickerCard widget', () {
    testWidgets('toggles between Book for Now and Schedule for Later',
        (tester) async {
      BookingSchedule? active;

      await tester.pumpWidget(
        host(
          FixSchedulePickerCard(
            onScheduleChanged: (s) => active = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arrival Schedule'), findsOneWidget);
      expect(find.text('Book for Now'), findsOneWidget);
      expect(find.text('Schedule for Later'), findsOneWidget);
      expect(find.textContaining('Immediate dispatch'), findsOneWidget);

      // Tap Schedule for Later
      await tester.tap(find.text('Schedule for Later'));
      await tester.pumpAndSettle();

      expect(active?.isNow, isFalse);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Select Preferred Arrival Window'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);

      // Tap Evening slot
      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();

      expect(active?.slot.id, 'evening');
    });
  });

  group('ServiceRequestScreen schedule integration', () {
    testWidgets('submits booking with scheduledAt timestamp when later is picked',
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

      const category = ServiceCategory(
        id: 'cat-plumbing',
        name: 'Plumbing Service',
        slug: 'plumbing',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ServiceRequestScreen(
              category: category,
              controller: controller,
              initialDescription: 'Leaking bathroom pipe needs scheduled visit.',
              locationProvider: _FixedLocation(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Schedule for Later
      await tester.scrollUntilVisible(
        find.text('Schedule for Later'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Schedule for Later'));
      await tester.pumpAndSettle();

      // Submit booking
      await tester.scrollUntilVisible(
        find.widgetWithText(FixButton, 'Find a verified provider'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FixButton, 'Find a verified provider'));
      await tester.pumpAndSettle();

      // Verify that scheduledAt was included in the API request body
      expect(fakeTransport.sentBody, isNotNull);
      expect(fakeTransport.sentBody!['scheduledAt'], isNotNull);
      expect(fakeTransport.sentBody!['serviceCategoryId'], 'cat-plumbing');
    });
  });
}

class _FixedLocation implements BookingLocationProvider {
  @override
  Future<BookingLocationFix> resolve() async => BookingLocationFix(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      );
}

class _FakeTransport implements ApiTransport {
  Map<String, dynamic>? sentBody;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method == ApiMethod.post && request.path == 'bookings') {
      sentBody = request.body as Map<String, dynamic>?;
      return ApiResponse(
        statusCode: 201,
        body: {
          'booking': {
            'id': 'booking-sched-123',
            'serviceCategoryId': 'cat-plumbing',
            'status': 'REQUESTED',
            'description': sentBody?['description'] ?? '',
            'locationLat': 12.9716,
            'locationLng': 77.5946,
            'createdAt': DateTime.now().toIso8601String(),
            'version': 1,
          }
        },
      );
    }
    return const ApiResponse(statusCode: 200, body: {});
  }
}
