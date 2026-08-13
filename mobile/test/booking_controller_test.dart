import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates an idempotent authenticated booking and exposes it', () async {
    final transport = _Transport();
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );

    await controller.create(
      serviceCategoryId: '11111111-1111-4111-8111-111111111111',
      description: 'Kitchen sink is leaking underneath.',
      latitude: 17.385,
      longitude: 78.4867,
    );

    expect(controller.status, BookingListStatus.ready);
    expect(controller.bookings.single.status, 'REQUESTED');
    final request = transport.requests.single;
    expect(request.bearerToken, 'token');
    expect(request.headers['Idempotency-Key'], startsWith('mobile-'));
    expect(request.body?['locationLat'], 17.385);
  });

  test('loads empty booking history', () async {
    final transport = _Transport(history: true);
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );

    await controller.load();

    expect(controller.status, BookingListStatus.empty);
  });
}

class _Transport implements ApiTransport {
  _Transport({this.history = false});
  final bool history;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (history) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    return const ApiResponse(
      statusCode: 201,
      body: {
        'booking': {
          'id': '22222222-2222-4222-8222-222222222222',
          'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
          'status': 'REQUESTED',
          'description': 'Kitchen sink is leaking underneath.',
          'createdAt': '2026-08-13T12:00:00.000Z',
        },
      },
    );
  }
}
