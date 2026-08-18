import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';

class BookingRepository {
  BookingRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
  }) : _api = api,
       _accessToken = accessToken;
  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  Future<List<CustomerBooking>> history() async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings?limit=30',
        bearerToken: await _token(),
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final rows = body?['bookings'];
    if (rows is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The booking history was invalid.',
      );
    }
    try {
      return rows
          .map(
            (row) =>
                CustomerBooking.fromJson(Map<String, Object?>.from(row as Map)),
          )
          .toList(growable: false);
    } on Object {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The booking history was invalid.',
      );
    }
  }

  Future<CustomerBooking> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
  }) async {
    final key = 'mobile-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings',
        bearerToken: await _token(),
        headers: {'Idempotency-Key': key},
        body: {
          'serviceCategoryId': serviceCategoryId,
          'description': description.trim(),
          'locationLat': latitude,
          'locationLng': longitude,
        },
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final raw = body?['booking'];
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The booking response was invalid.',
      );
    }
    return CustomerBooking.fromJson(Map<String, Object?>.from(raw));
  }

  Future<CustomerBooking> cancel({
    required CustomerBooking booking,
    required String reason,
  }) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/${booking.id}/cancel',
        bearerToken: await _token(),
        body: {'reason': reason.trim(), 'expectedVersion': booking.version},
      ),
    );
    final body = response.body;
    final raw = body is Map<String, dynamic> ? body['booking'] : null;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The cancellation response was invalid.',
      );
    }
    return CustomerBooking.fromJson(Map<String, Object?>.from(raw));
  }

  Future<String> _token() async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in required.',
      );
    }
    return token;
  }
}
