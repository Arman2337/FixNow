enum TrackingConnection { connecting, live, reconciling, offline }

enum LocationAvailability { live, stale, unavailable }

class BookingTracking {
  const BookingTracking({
    required this.bookingId,
    required this.status,
    required this.sequence,
    required this.locationAvailability,
    this.estimatedMinutes,
  });

  final String bookingId;
  final String status;
  final int sequence;
  final LocationAvailability locationAvailability;
  final int? estimatedMinutes;
}

abstract interface class BookingTrackingSource {
  Future<BookingTracking> fetchSnapshot(String bookingId);
}
