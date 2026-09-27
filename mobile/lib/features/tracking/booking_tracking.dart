import 'package:fixnow_mobile/features/bookings/booking.dart';

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
    this.serviceStartOtp,
    this.providerName,
    this.providerRating,
    this.providerJobsCount,
    this.items = const [],
    this.pricing,
  });

  final String bookingId;
  final String status;
  final int sequence;
  final LocationAvailability locationAvailability;
  final int? estimatedMinutes;
  final ProviderMapLocation? providerLocation;
  final CustomerMapLocation? customerLocation;
  final DrivingRoute? route;
  final String? serviceStartOtp;
  final String? providerName;
  final double? providerRating;
  final int? providerJobsCount;

  /// Server-persisted line items. Empty when the booking has none, which the UI
  /// must state rather than replace with invented rows.
  final List<BookingLineItem> items;

  /// Server-computed totals, including GST. Null until the booking is
  /// itemized, so the UI shows "not available" instead of a made-up figure.
  final BookingPricing? pricing;
}

abstract interface class BookingTrackingSource {
  Future<BookingTracking> fetchSnapshot(String bookingId);

  /// Returns the 4-digit service-start OTP, or null when the booking is not
  /// en route yet.
  Future<String?> fetchServiceStartOtp(String bookingId);
}
