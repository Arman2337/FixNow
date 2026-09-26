import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CustomerBooking bookingWithItems({
    required List<BookingLineItem> items,
    BookingPricing? pricing,
  }) => CustomerBooking(
        id: 'booking-1',
        serviceCategoryId: 'plumbing',
        status: 'ASSIGNED',
        description: 'Repair a leaking pipe',
        createdAt: DateTime(2026, 9, 1),
        version: 1,
        items: items,
        pricing: pricing,
      );

  testWidgets('renders item name, quantity, and line total', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(
          booking: bookingWithItems(
            items: const [
              BookingLineItem(
                id: 'line-1',
                name: 'Leak inspection',
                quantity: 2,
                unitPriceMinor: 25000,
              ),
            ],
            pricing: const BookingPricing(
              subtotalMinor: 50000,
              gstMinor: 9000,
              totalMinor: 59000,
              currency: 'INR',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Leak inspection ×2'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);
  });

  testWidgets('renders a single item without a multiplication symbol', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(
          booking: bookingWithItems(
            items: const [
              BookingLineItem(
                id: 'line-1',
                name: 'Leak inspection',
                quantity: 1,
                unitPriceMinor: 25000,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Leak inspection'), findsOneWidget);
    expect(find.text('Leak inspection ×1'), findsNothing);
  });

  testWidgets('does not render an empty booked services section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingDetailScreen(
          booking: bookingWithItems(items: const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BOOKED SERVICES'), findsNothing);
  });
}
