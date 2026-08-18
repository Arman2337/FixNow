import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ignores stale events and reconciles a sequence gap from snapshot',
    () async {
      final source = _Source(_tracking(sequence: 5));
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      await controller.loadSnapshot();
      await controller.applyRealtime(_tracking(sequence: 4));
      expect(controller.tracking?.sequence, 5);
      source.value = _tracking(sequence: 8);
      await controller.applyRealtime(_tracking(sequence: 7));
      expect(controller.tracking?.sequence, 8);
      expect(source.calls, 2);
    },
  );

  test('accepts location updates that reuse the current sequence', () async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(
        _tracking(sequence: 5, availability: LocationAvailability.unavailable),
      ),
    );
    await controller.loadSnapshot();
    
    // Simulate a realtime location update that does not bump the booking sequence.
    await controller.applyRealtime(
      _tracking(sequence: 5, availability: LocationAvailability.live),
    );
    
    expect(
      controller.tracking?.locationAvailability,
      LocationAvailability.live,
    );
  });

  test('preserves last status and reports offline on disconnect', () async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(_tracking(sequence: 1)),
    );
    await controller.loadSnapshot();
    controller.markDisconnected();
    expect(controller.connection, TrackingConnection.offline);
    expect(controller.tracking?.sequence, 1);
  });

  testWidgets('shows honest ETA, unavailable location, and retry fallback', (
    tester,
  ) async {
    final source = _Source(
      _tracking(
        sequence: 1,
        availability: LocationAvailability.unavailable,
        eta: null,
      ),
    );
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: source,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingTrackingScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Provider is on the way'), findsOneWidget);
    expect(find.text('Live location unavailable'), findsOneWidget);
    expect(find.text('ETA unavailable'), findsOneWidget);
    controller.markDisconnected();
    await tester.pump();
    expect(find.text('Updates paused'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

BookingTracking _tracking({
  required int sequence,
  LocationAvailability availability = LocationAvailability.live,
  int? eta = 12,
}) => BookingTracking(
  bookingId: 'booking-1',
  status: 'EN_ROUTE',
  sequence: sequence,
  locationAvailability: availability,
  estimatedMinutes: eta,
);

class _Source implements BookingTrackingSource {
  _Source(this.value);
  BookingTracking value;
  int calls = 0;
  @override
  Future<BookingTracking> fetchSnapshot(String bookingId) async {
    calls += 1;
    return value;
  }
}
