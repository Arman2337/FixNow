import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'customer cancellation uses the booking version and updates history',
    () async {
      final transport = _Transport();
      final controller = BookingController(
        BookingRepository(api: transport, accessToken: () async => 'token'),
      )..bookings = [_booking()];

      final updated = await controller.cancel(_booking(), 'No longer needed');

      expect(updated.status, 'CANCELLED');
      expect(transport.request?.path, 'bookings/booking-1/cancel');
      expect(transport.request?.body, {
        'reason': 'No longer needed',
        'expectedVersion': 3,
      });
      expect(controller.bookings.single.status, 'CANCELLED');
    },
  );

  testWidgets('cancellation is offered only in customer-allowed states', (
    tester,
  ) async {
    Future<CustomerBooking> cancel(String _) async =>
        _booking(status: 'CANCELLED');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(booking: _booking(), onCancel: cancel),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cancel booking'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancel booking'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(
          booking: _booking(status: 'COMPLETED'),
          onCancel: cancel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancel booking'), findsNothing);
  });

  test('provider cancellation uses the assigned booking version', () async {
    final transport = _Transport();
    final repository = ProviderRepository(
      api: transport,
      accessToken: () async => 'token',
    );

    await repository.cancelJob(_booking(), 'Provider unavailable');

    expect(transport.request?.path, 'bookings/booking-1/cancel');
    expect(transport.request?.body, {
      'reason': 'Provider unavailable',
      'expectedVersion': 3,
    });
  });
}

CustomerBooking _booking({String status = 'ASSIGNED'}) => CustomerBooking(
  id: 'booking-1',
  serviceCategoryId: 'category-1',
  status: status,
  description: 'Repair a leaking pipe',
  createdAt: DateTime.utc(2026, 8, 14),
  version: 3,
);

class _Transport implements ApiTransport {
  ApiRequest? request;

  @override
  Future<ApiResponse> send(ApiRequest value) async {
    request = value;
    return ApiResponse(
      statusCode: 200,
      body: {
        'booking': {
          'id': 'booking-1',
          'serviceCategoryId': 'category-1',
          'status': 'CANCELLED',
          'description': 'Repair a leaking pipe',
          'createdAt': '2026-08-14T00:00:00.000Z',
          'version': 4,
        },
      },
    );
  }
}
