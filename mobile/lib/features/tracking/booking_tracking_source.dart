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
        path: 'bookings/$bookingId',
        bearerToken: token,
      ),
    );
    final body = response.body;
    final raw = body is Map<String, dynamic> ? body['booking'] : null;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The booking snapshot was invalid.',
      );
    }
    final booking = CustomerBooking.fromJson(
      Map<String, Object?>.from(raw),
    );
    String? serviceStartOtp;
    if (booking.status == 'EN_ROUTE') {
      serviceStartOtp = await fetchServiceStartOtp(bookingId);
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

  @override
  Future<String?> fetchServiceStartOtp(String bookingId) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in required.',
      );
    }
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
      return value;
    }
    return null;
  }
}
