import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedLocation implements BookingLocationProvider {
  @override
  Future<BookingLocationFix> resolve() async => BookingLocationFix(
    latitude: 17.385,
    longitude: 78.4867,
    accuracyMeters: 8,
    timestamp: DateTime.now(),
  );
}

class _Transport implements ApiTransport {
  _Transport({this.failWith});
  final ApiFailureKind? failWith;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (failWith != null) {
      throw ApiException(failWith!, 'offline');
    }
    if (request.method == ApiMethod.get) {
      return ApiResponse(
        statusCode: 200,
        body: {
          'bookings': [
            {
              'id': 'aaaaaaaa-1111-4111-8111-111111111111',
              'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
              'status': 'COMPLETED',
              'description': 'Kitchen sink leaking underneath.',
              'createdAt': '2026-08-20T10:00:00.000Z',
              'version': 3,
            },
            {
              'id': 'bbbbbbbb-2222-4222-8222-222222222222',
              'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
              'status': 'REQUESTED',
              'description': 'Fan not working.',
              'createdAt': '2026-08-23T10:00:00.000Z',
              'version': 1,
            },
          ],
          'nextCursor': null,
        },
      );
    }
    return const ApiResponse(
      statusCode: 201,
      body: {
        'booking': {
          'id': 'cccccccc-3333-4333-8333-333333333333',
          'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
          'status': 'REQUESTED',
          'description': 'created',
          'createdAt': '2026-08-24T10:00:00.000Z',
          'version': 1,
        },
      },
    );
  }
}

CustomerBooking _booking(String status) => CustomerBooking(
  id: 'aaaaaaaa-1111-4111-8111-111111111111',
  serviceCategoryId: '11111111-1111-4111-8111-111111111111',
  status: status,
  description: 'Kitchen sink leaking underneath.',
  createdAt: DateTime(2026, 8, 20),
  version: 3,
);

const _category = ServiceCategory(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Plumbing',
  slug: 'plumbing',
);

void main() {
  testWidgets('completed booking detail offers book again and fires it', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BookingDetailScreen(
            booking: _booking('COMPLETED'),
            onBookAgain: () => opened = true,
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Book again'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Book again'), findsOneWidget);
    expect(find.textContaining('not guaranteed'), findsOneWidget);
    await tester.tap(find.text('Book again'));
    expect(opened, isTrue);
  });

  testWidgets('active bookings do not offer book again on detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BookingDetailScreen(booking: _booking('REQUESTED')),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Full booking ID'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Book again'), findsNothing);
  });

  testWidgets('history shows book again only on completed entries and passes '
      'that booking', (tester) async {
    CustomerBooking? requested;
    final controller = BookingController(
      BookingRepository(api: _Transport(), accessToken: () async => 'token'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CustomerBookingsScreen(
            controller: controller,
            onBookAgain: (booking) => requested = booking,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Active filter first: the completed entry must not expose the action.
    expect(find.text('Book again'), findsNothing);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Book again'), findsOneWidget);

    await tester.tap(find.text('Book again'));
    expect(requested?.status, 'COMPLETED');
  });

  testWidgets('prefilled request keeps prior description editable before an '
      'ordinary submission', (tester) async {
    final transport = _Transport();
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceRequestScreen(
            category: _category,
            controller: controller,
            locationProvider: _FixedLocation(),
            initialDescription: 'Kitchen sink leaking underneath.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Kitchen sink leaking underneath.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Kitchen sink leaking again; same issue as last visit.',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FixButton, 'Find a verified provider'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FixButton, 'Find a verified provider'));
    await tester.pumpAndSettle();

    expect(controller.bookings.single.status, 'REQUESTED');
    expect(
      transport.requests
          .where((request) => request.method != ApiMethod.get)
          .single
          .body?['description'],
      'Kitchen sink leaking again; same issue as last visit.',
    );
  });

  testWidgets('offline submission shows honest failure without creating', (
    tester,
  ) async {
    final controller = BookingController(
      BookingRepository(
        api: _Transport(failWith: ApiFailureKind.offline),
        accessToken: () async => 'token',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceRequestScreen(
            category: _category,
            controller: controller,
            locationProvider: _FixedLocation(),
            initialDescription: 'Kitchen sink leaking underneath.',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.widgetWithText(FixButton, 'Find a verified provider'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FixButton, 'Find a verified provider'));
    await tester.pump();

    expect(
      find.text('You are offline. Reconnect and try again.'),
      findsOneWidget,
    );
    expect(controller.bookings, isEmpty);
  });
}
