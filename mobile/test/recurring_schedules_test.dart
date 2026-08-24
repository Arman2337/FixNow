import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transport serving one active and one paused schedule plus empty bookings.
class _Transport implements ApiTransport {
  _Transport({this.failSchedules = false});
  final bool failSchedules;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path.startsWith('bookings/schedules')) {
      if (failSchedules) {
        throw const ApiException(ApiFailureKind.server, 'boom');
      }
      if (request.method == ApiMethod.get) {
        return ApiResponse(
          statusCode: 200,
          body: [
            {
              'id': '11111111-1111-4111-8111-111111111111',
              'serviceCategoryId': '22222222-2222-4222-8222-222222222222',
              'description': 'Weekly deep clean.',
              'locationLat': 17.385,
              'locationLng': 78.4867,
              'cadence': 'WEEKLY',
              'status': 'ACTIVE',
              'nextOccurrenceAt': '2026-08-31T04:30:00.000Z',
            },
            {
              'id': '33333333-3333-4333-8333-333333333333',
              'serviceCategoryId': '22222222-2222-4222-8222-222222222222',
              'description': 'Monthly garden care.',
              'locationLat': 17.385,
              'locationLng': 78.4867,
              'cadence': 'MONTHLY',
              'status': 'PAUSED',
              'nextOccurrenceAt': null,
            },
          ],
        );
      }
      if (request.path.endsWith('/confirm')) {
        return ApiResponse(
          statusCode: 201,
          body: {
            'booking': {
              'id': '44444444-4444-4444-8444-444444444444',
              'serviceCategoryId': '22222222-2222-4222-8222-222222222222',
              'status': 'REQUESTED',
              'description': 'Weekly deep clean.',
              'createdAt': '2026-08-24T10:00:00.000Z',
              'version': 1,
            },
            'schedule': <String, Object?>{},
          },
        );
      }
      return ApiResponse(statusCode: 200, body: <String, Object?>{});
    }
    return const ApiResponse(
      statusCode: 200,
      body: {'bookings': <Object?>[], 'nextCursor': null},
    );
  }
}

void main() {
  BookingRepository repo(transport) =>
      BookingRepository(api: transport, accessToken: () async => 'token');

  testWidgets('shows repeating services with honest next-visit states', (
    tester,
  ) async {
    final schedules = SchedulesController(repo(_Transport()));
    final bookings = BookingController(
      repo(_Transport()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CustomerBookingsScreen(
            controller: bookings,
            schedulesController: schedules,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeating services'), findsOneWidget);
    expect(find.text('Every week'), findsOneWidget);
    expect(find.text('Every month'), findsOneWidget);
    expect(find.textContaining('Next visit:'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('Paused. Resume to see'), findsOneWidget);
    // Paused schedules generate nothing to confirm.
    expect(find.text('Confirm visit'), findsOneWidget);
  });

  testWidgets('confirming a visit books it through the confirm endpoint', (
    tester,
  ) async {
    var confirmedBooked = false;
    final transport = _Transport();
    final schedules = SchedulesController(repo(transport));
    final bookings = BookingController(repo(_Transport()));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CustomerBookingsScreen(
            controller: bookings,
            schedulesController: schedules,
            onOccurrenceConfirmed: () => confirmedBooked = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm visit'));
    await tester.pumpAndSettle();

    expect(confirmedBooked, isTrue);
    expect(
      transport.requests.any(
        (request) => request.path.endsWith('/confirm'),
      ),
      isTrue,
    );
  });

  testWidgets('an unavailable repeating-services section stays honest', (
    tester,
  ) async {
    final schedules = SchedulesController(repo(_Transport(failSchedules: true)));
    final bookings = BookingController(
      repo(_Transport()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CustomerBookingsScreen(
            controller: bookings,
            schedulesController: schedules,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeating services are unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
