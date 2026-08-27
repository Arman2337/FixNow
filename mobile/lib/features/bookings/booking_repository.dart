import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:fixnow_mobile/features/ratings/booking_review.dart';
import 'package:fixnow_mobile/features/ratings/review_photo.dart';

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
    DateTime? scheduledAt,
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
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
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

  /// FN-110 review photos.
  Future<List<ReviewPhoto>> reviewPhotos(String bookingId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$bookingId/review/photos',
        bearerToken: await _token(),
      ),
    );
    final items = response.body;
    if (items is! List) return const [];
    return items
        .map(
          (item) => ReviewPhoto.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> attachReviewPhoto({
    required String bookingId,
    required String contentType,
    required List<int> bytes,
  }) async {
    final api = _api;
    if (api is! ApiClient) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Photo upload is unavailable.',
      );
    }
    await api.uploadFile(
      path: 'bookings/$bookingId/review/photos',
      bearerToken: await _token(),
      fieldName: 'photo',
      fileName: 'review-photo',
      contentType: contentType,
      bytes: bytes,
    );
  }

  /// FN-112 recurring schedules.
  Future<List<RecurringSchedule>> schedules() async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/schedules',
        bearerToken: await _token(),
      ),
    );
    final items = response.body;
    if (items is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The repeating services list was invalid.',
      );
    }
    return items
        .map((item) => RecurringSchedule.fromJson(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> confirmSchedule(String scheduleId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/schedules/$scheduleId/confirm',
        bearerToken: await _token(),
      ),
    );
    return Map<String, Object?>.from(response.body as Map);
  }

  Future<Map<String, Object?>> scheduleAction(
    String scheduleId,
    String action,
  ) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.patch,
        path: 'bookings/schedules/$scheduleId/status',
        bearerToken: await _token(),
        body: {'action': action},
      ),
    );
    return Map<String, Object?>.from(response.body as Map);
  }

  Future<BookingReview?> reviewFor(String bookingId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$bookingId/review',
        bearerToken: await _token(),
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final raw = body?['review'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The review response was invalid.',
      );
    }
    return BookingReview.fromJson(Map<String, Object?>.from(raw));
  }

  Future<BookingReview> createReview({
    required String bookingId,
    required int rating,
    required String reviewText,
  }) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/review',
        bearerToken: await _token(),
        body: {
          'rating': rating,
          if (reviewText.trim().isNotEmpty) 'reviewText': reviewText.trim(),
        },
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final raw = body?['review'];
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The review response was invalid.',
      );
    }
    return BookingReview.fromJson(Map<String, Object?>.from(raw));
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
