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

/// The destination selected by the customer when the booking was created.
/// This is intentionally separate from the provider's live location: it is a
/// booking detail, not a fresh device-location reading.
class CustomerMapLocation {
  const CustomerMapLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class DrivingRoute {
  const DrivingRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.coordinates,
  });

  final double distanceMeters;
  final int durationSeconds;
  final List<CustomerMapLocation> coordinates;
}

class BookingTracking {
  const BookingTracking({
    required this.bookingId,
    required this.status,
    required this.sequence,
    required this.locationAvailability,
    this.estimatedMinutes,
    this.providerLocation,
    this.customerLocation,
    this.route,
  });

  final String bookingId;
  final String status;
  final int sequence;
  final LocationAvailability locationAvailability;
  final int? estimatedMinutes;
  final ProviderMapLocation? providerLocation;
  final CustomerMapLocation? customerLocation;
  final DrivingRoute? route;
}

abstract interface class BookingTrackingSource {
  Future<BookingTracking> fetchSnapshot(String bookingId);
}
