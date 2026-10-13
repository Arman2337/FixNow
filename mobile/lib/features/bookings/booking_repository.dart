import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_controller.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:fixnow_mobile/features/ratings/booking_review.dart';
import 'package:fixnow_mobile/features/ratings/review_photo.dart';

class BookingRepository {
  BookingRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
    BinaryDownloader? downloader,
  }) : _api = api,
       _accessToken = accessToken,
       _downloader = downloader;
  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  /// FN-144. Supplies the bytes for photos the backend stores privately. Null
  /// on a transport that cannot fetch bytes, in which case the UI says so
  /// rather than drawing a placeholder that looks like a real photo.
  final BinaryDownloader? _downloader;

  /// The downloader, or null when this repository cannot fetch photo bytes.
  BinaryDownloader? get downloader => _downloader;

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

  Future<CustomerBooking> get(String id) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$id',
        bearerToken: await _token(),
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

  Future<CustomerBooking> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
    DateTime? scheduledAt,
    List<BookingItemDraft>? items,
    String? idempotencyKey,
  }) async {
    final key =
        idempotencyKey ?? 'mobile-${DateTime.now().toUtc().millisecondsSinceEpoch}';
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
          if (scheduledAt != null)
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          if (items != null && items.isNotEmpty)
            'items': items.map((item) => item.toJson()).toList(),
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

  Future<CustomerBooking> reschedule({
    required CustomerBooking booking,
    required DateTime newScheduledAt,
    String? reason,
  }) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/${booking.id}/reschedule',
        bearerToken: await _token(),
        body: {
          'newScheduledAt': newScheduledAt.toUtc().toIso8601String(),
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
          'expectedVersion': booking.version,
        },
      ),
    );
    final body = response.body;
    final raw = body is Map<String, dynamic> ? body['booking'] : null;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The reschedule response was invalid.',
      );
    }
    return CustomerBooking.fromJson(Map<String, Object?>.from(raw));
  }

  /// FN-110 review photos.
  /// FN-144. The `{ photos: [...] }` envelope the backend actually returns.
  ///
  /// This read previously parsed the body as a bare list, so it returned an
  /// empty list against the live API and the customer's review photos had never
  /// once appeared. A bare list is now rejected rather than silently treated as
  /// "no photos", because that silence is what hid the bug for so long.
  Future<List<ReviewPhoto>> reviewPhotos(String bookingId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$bookingId/review/photos',
        bearerToken: await _token(),
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final rows = body?['photos'];
    if (rows is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The review photos response was invalid.',
      );
    }
    try {
      return rows
          .map(
            (item) =>
                ReviewPhoto.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false);
    } on Object {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The review photos response was invalid.',
      );
    }
  }

  /// FN-144. The bytes behind an approved (or own) review photo.
  ///
  /// Fetched through the participant-checked content endpoint rather than
  /// assembled from a URL: the backend deliberately projects the storage key
  /// out of every response.
  Future<Uint8List> reviewPhotoBytes(
    String bookingId,
    String photoId,
    BinaryDownloader downloader,
  ) async {
    try {
      return await downloader.downloadFile(
        path: 'bookings/$bookingId/review/photos/$photoId/content',
        bearerToken: await _token(),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The review photo could not be read.',
      );
    }
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
        .map(
          (item) => RecurringSchedule.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
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

  /// FN-143. The before/after proof recorded for a booking.
  ///
  /// Reads the `{ photos: [...] }` envelope the backend actually returns, not a
  /// bare list. FN-110's review-photo read parses a bare list and therefore
  /// yields nothing against the live API; that defect is tracked as FN-144 and
  /// is deliberately not repeated here.
  Future<List<JobProofPhoto>> jobProofPhotos(String bookingId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$bookingId/job-proof/photos',
        bearerToken: await _token(),
      ),
    );
    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final rows = body?['photos'];
    if (rows is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The job proof response was invalid.',
      );
    }
    try {
      return rows
          .map(
            (row) =>
                JobProofPhoto.fromJson(Map<String, Object?>.from(row as Map)),
          )
          .toList(growable: false);
    } on Object {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The job proof response was invalid.',
      );
    }
  }

  /// The bytes behind one proof photograph, fetched through the
  /// participant-checked content endpoint. Never assembled from a URL: the
  /// backend deliberately projects the storage key out of every response.
  Future<Uint8List> jobProofBytes(
    String bookingId,
    String photoId,
    BinaryDownloader downloader,
  ) async {
    try {
      return await downloader.downloadFile(
        path: 'bookings/$bookingId/job-proof/photos/$photoId/content',
        bearerToken: await _token(),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The job proof photo could not be read.',
      );
    }
  }

  /// FN-143. Capture the before or after shot. Provider only — the backend
  /// refuses anyone who is not the pro assigned to the booking.
  Future<JobProofPhoto> captureJobProof({
    required String bookingId,
    required JobProofStage stage,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final api = _api;
    if (api is! ApiClient) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Job proof upload is unavailable.',
      );
    }
    await api.uploadFile(
      path: 'bookings/$bookingId/job-proof/photos',
      bearerToken: await _token(),
      fieldName: 'photo',
      fileName: 'job-proof-${stage.wireValue.toLowerCase()}',
      contentType: contentType,
      bytes: bytes,
      fields: {'stage': stage.wireValue},
    );
    // The upload answer is 201 with the stored photo; re-reading the list keeps
    // the client on one code path instead of parsing a second envelope shape.
    final photos = await jobProofPhotos(bookingId);
    return photos.firstWhere(
      (photo) => photo.stage == stage,
      orElse: () => throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The job proof response was invalid.',
      ),
    );
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
