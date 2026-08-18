enum TrackingConnection { connecting, live, reconciling, offline }

enum LocationAvailability { live, stale, unavailable }

class ProviderMapLocation {
  const ProviderMapLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.receivedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final DateTime receivedAt;
}

class BookingTracking {
  const BookingTracking({
    required this.bookingId,
    required this.status,
    required this.sequence,
    required this.locationAvailability,
    this.estimatedMinutes,
    this.providerLocation,
  });

  final String bookingId;
  final String status;
  final int sequence;
  final LocationAvailability locationAvailability;
  final int? estimatedMinutes;
  final ProviderMapLocation? providerLocation;
}

abstract interface class BookingTrackingSource {
  Future<BookingTracking> fetchSnapshot(String bookingId);
}
