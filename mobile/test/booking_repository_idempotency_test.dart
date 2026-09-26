import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reuses a caller-provided idempotency key for a retried booking',
    () async {
      final transport = _RecordingTransport();
      final repository = BookingRepository(
        api: transport,
        accessToken: () async => 'token',
      );

      await repository.create(
        serviceCategoryId: 'plumbing',
        description: 'Leaking pipe',
        latitude: 12.3,
        longitude: 45.6,
        idempotencyKey: 'submission-1',
      );
      await repository.create(
        serviceCategoryId: 'plumbing',
        description: 'Leaking pipe',
        latitude: 12.3,
        longitude: 45.6,
        idempotencyKey: 'submission-1',
      );

      expect(
        transport.requests.map((request) => request.headers['Idempotency-Key']),
        ['submission-1', 'submission-1'],
      );
    },
  );
}

class _RecordingTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return const ApiResponse(
      statusCode: 200,
      body: {
        'booking': {
          'id': 'booking-1',
          'serviceCategoryId': 'plumbing',
          'status': 'REQUESTED',
          'description': 'Leaking pipe',
          'createdAt': '2026-09-24T10:00:00.000Z',
          'version': 1,
        },
      },
    );
  }
}
