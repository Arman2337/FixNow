import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'completed booking offers accessible star review and submits it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final transport = _Transport();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingDetailScreen(
            booking: _booking('COMPLETED'),
            reviewRepository: BookingRepository(
              api: transport,
              accessToken: () async => 'token',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('How was your experience?'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('How was your experience?'), findsOneWidget);
      expect(find.bySemanticsLabel('5 stars'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('5 stars'));
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();
      expect(transport.postBody, {'rating': 5});
      expect(find.text('Thanks for your feedback'), findsOneWidget);
    },
  );

  testWidgets('non-completed booking has no review controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(booking: _booking('IN_PROGRESS')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('How was your experience?'), findsNothing);
  });
}

CustomerBooking _booking(String status) => CustomerBooking(
  id: 'booking-1',
  serviceCategoryId: 'category-1',
  status: status,
  description: 'Repair a leaking pipe',
  createdAt: DateTime.utc(2026, 8, 21),
  version: 1,
);

class _Transport implements ApiTransport {
  Map<String, Object?>? postBody;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method == ApiMethod.get)
      return const ApiResponse(statusCode: 200, body: {'review': null});
    postBody = Map<String, Object?>.from(request.body! as Map);
    return ApiResponse(
      statusCode: 201,
      body: {
        'review': {
          'id': 'review-1',
          'rating': 5,
          'reviewText': null,
          'moderationStatus': 'PUBLISHED',
          'createdAt': '2026-08-21T00:00:00.000Z',
        },
      },
    );
  }
}
