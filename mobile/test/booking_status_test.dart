import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses only statuses supported by the backend booking contract', () {
    expect(BookingStatusValue.parse('REQUESTED'), BookingStatusValue.requested);
    expect(BookingStatusValue.parse('ASSIGNED'), BookingStatusValue.assigned);
    expect(BookingStatusValue.parse('EN_ROUTE'), BookingStatusValue.enRoute);
    expect(BookingStatusValue.parse('IN_PROGRESS'), BookingStatusValue.inProgress);
    expect(BookingStatusValue.parse('COMPLETED'), BookingStatusValue.completed);
    expect(BookingStatusValue.parse('CANCELLED'), BookingStatusValue.cancelled);
    expect(BookingStatusValue.parse('accepted'), BookingStatusValue.unknown);
    expect(BookingStatusValue.parse('expired'), BookingStatusValue.unknown);
    expect(BookingStatusValue.parse(''), BookingStatusValue.unknown);
  });

  test('unknown status is never treated as active or successful', () {
    expect(BookingStatusValue.unknown.isActive, isFalse);
    expect(BookingStatusValue.unknown.isCompleted, isFalse);
    expect(BookingStatusValue.unknown.isCancelled, isFalse);
    expect(BookingStatusValue.unknown.label, 'Status unavailable');
  });

  test('customer booking exposes the canonical parsed status', () {
    final booking = CustomerBooking(
      id: 'booking-id',
      serviceCategoryId: 'category-id',
      status: 'EN_ROUTE',
      description: 'Repair request',
      createdAt: DateTime.utc(2026, 9, 16),
      version: 2,
    );

    expect(booking.statusValue, BookingStatusValue.enRoute);
    expect(booking.statusValue.label, 'En route');
  });
}
