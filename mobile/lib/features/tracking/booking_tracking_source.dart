import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';

class ApiBookingTrackingSource implements BookingTrackingSource {
  ApiBookingTrackingSource({required this.api, required this.accessToken});
  final ApiTransport api;
  final Future<String?> Function() accessToken;

  @override
  Future<BookingTracking> fetchSnapshot(String bookingId) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in required.',
      );
    }
    final response = await api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings?limit=30',
        bearerToken: token,
      ),
    );
    final body = response.body;
    final rows = body is Map<String, dynamic> ? body['bookings'] : null;
    if (rows is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The booking snapshot was invalid.',
      );
    }
    final booking = rows
        .map(
          (row) =>
              CustomerBooking.fromJson(Map<String, Object?>.from(row as Map)),
        )
        .cast<CustomerBooking>()
        .firstWhere((item) => item.id == bookingId);
    String? serviceStartOtp;
    if (booking.status == 'EN_ROUTE') {
      final otpResponse = await api.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'bookings/$bookingId/service-start-otp',
          bearerToken: token,
        ),
      );
      final body = otpResponse.body;
      final value = body is Map ? body['otp'] : null;
      if (value is String && RegExp(r'^\d{4}$').hasMatch(value)) {
        serviceStartOtp = value;
      }
    }
    return BookingTracking(
      bookingId: booking.id,
      status: booking.status,
      sequence: booking.version,
      locationAvailability: LocationAvailability.unavailable,
      customerLocation:
          booking.locationLatitude != null && booking.locationLongitude != null
          ? CustomerMapLocation(
              latitude: booking.locationLatitude!,
              longitude: booking.locationLongitude!,
            )
          : null,
      serviceStartOtp: serviceStartOtp,
    );
  }
}
