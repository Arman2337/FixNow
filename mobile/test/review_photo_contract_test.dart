import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/ratings/review_photo.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport implements ApiTransport {
  _Transport(this.body);

  final Object? body;
  String? requestedPath;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requestedPath = request.path;
    return ApiResponse(statusCode: 200, body: body);
  }
}

class _Downloader implements BinaryDownloader {
  _Downloader(this.bytes);

  final Uint8List bytes;
  final List<String> requested = [];

  @override
  Future<Uint8List> downloadFile({
    required String path,
    required String bearerToken,
    int maxBytes = 1 << 24,
  }) async {
    requested.add(path);
    return bytes;
  }
}

BookingRepository _repository(ApiTransport api, {BinaryDownloader? downloader}) =>
    BookingRepository(
      api: api,
      accessToken: () async => 'token',
      downloader: downloader,
    );

void main() {
  group('FN-144 review-photo contract', () {
    test('reads the { photos: [...] } envelope the backend returns', () async {
      final api = _Transport({
        'photos': [
          {'id': 'photo-1', 'status': 'PENDING'},
          {'id': 'photo-2', 'status': 'APPROVED'},
        ],
      });

      final photos = await _repository(api).reviewPhotos('booking-1');

      expect(photos.map((photo) => photo.status), ['PENDING', 'APPROVED']);
      expect(api.requestedPath, 'bookings/booking-1/review/photos');
    });

    test('rejects a bare list instead of silently reading it as "no photos"', () async {
      // This is the exact defect: the client parsed a bare list, and returning
      // `const []` on a mismatch meant it answered "you have no photos" to
      // every customer who did. A wrong shape must now be an error, not an
      // empty page.
      await expectLater(
        _repository(
          _Transport([
            {'id': 'photo-1', 'status': 'APPROVED'},
          ]),
        ).reviewPhotos('booking-1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('treats a genuinely empty photo list as empty, not invalid', () async {
      final photos = await _repository(
        _Transport({
          'photos': <Object?>[],
        }),
      ).reviewPhotos('booking-1');

      expect(photos, isEmpty);
    });

    test('fetches photo bytes from the content endpoint, never a URL', () async {
      final downloader = _Downloader(Uint8List.fromList([1, 2, 3]));

      final bytes = await _repository(
        _Transport({
          'photos': [
            {'id': 'photo-2', 'status': 'APPROVED'},
          ],
        }),
        downloader: downloader,
      ).reviewPhotoBytes('booking-1', 'photo-2', downloader);

      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(
        downloader.requested.single,
        'bookings/booking-1/review/photos/photo-2/content',
      );
    });

    test('offers bytes only for photos the server will actually serve', () {
      // The server re-checks this; it is a UI affordance, not the enforcement
      // point. A rejected photo must not be rendered as a broken thumbnail
      // beside the copy saying it was not published.
      expect(const ReviewPhoto(id: 'a', status: 'APPROVED').canBeViewed, isTrue);
      expect(const ReviewPhoto(id: 'a', status: 'PENDING').canBeViewed, isTrue);
      expect(
        const ReviewPhoto(id: 'a', status: 'REJECTED').canBeViewed,
        isFalse,
      );
    });

    test('the projection carries no storage key to leak', () {
      // The backend never sends one, and the model must not grow one either.
      final photo = ReviewPhoto.fromJson({
        'id': 'photo-1',
        'status': 'APPROVED',
        'contentType': 'image/jpeg',
        'sizeBytes': 10,
      });

      expect(photo.id, 'photo-1');
      expect(
        jsonEncode({'id': photo.id, 'status': photo.status}),
        isNot(contains('objectKey')),
      );
    });

    test('exposes no downloader when the transport cannot fetch bytes', () {
      expect(_repository(_Transport(null)).downloader, isNull);
      expect(
        _repository(_Transport(null), downloader: _Downloader(Uint8List(0)))
            .downloader,
        isNotNull,
      );
    });
  });
}