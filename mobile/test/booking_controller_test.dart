import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
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

  test('fires acceptedBooking exactly once on REQUESTED→ASSIGNED', () async {
    final socket = _FakeSocket();
    final controller = BookingController(
      BookingRepository(
        api: _Transport(activeBooking: true),
        accessToken: () async => 'token',
      ),
      realtime: RealtimeClient(
        uri: Uri.parse('wss://realtime.example.test/socket'),
        accessToken: () async => 'token',
        connector: _FakeConnector(socket),
      ),
    );

    await controller.load();
    expect(controller.bookings.single.status, 'REQUESTED');
    await controller.startRealtime();
    await Future<void>.delayed(Duration.zero);

    // Stale sequence must stay silent.
    socket.emitProjection(status: 'ASSIGNED', sequence: 1);
    await Future<void>.delayed(Duration.zero);
    expect(controller.acceptedBooking.value, isNull);
    expect(controller.bookings.single.status, 'REQUESTED');

    // The acceptance beat: REQUESTED → ASSIGNED.
    socket.emitProjection(status: 'ASSIGNED', sequence: 2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.acceptedBooking.value, '22222222-2222-4222-8222-222222222222');
    expect(controller.bookings.single.status, 'ASSIGNED');
    // Projection rebuilds must carry forward location and schedule fields.
    expect(controller.bookings.single.locationLatitude, 17.385);
    expect(controller.bookings.single.locationLongitude, 78.4867);
    expect(controller.bookings.single.scheduledAt, isNotNull);

    // One-shot: later transitions do not re-fire.
    socket.emitProjection(status: 'EN_ROUTE', sequence: 3);
    await Future<void>.delayed(Duration.zero);
    expect(controller.acceptedBooking.value, '22222222-2222-4222-8222-222222222222');

    controller.dispose();
  });
}

class _FakeConnector implements RealtimeSocketConnector {
  _FakeConnector(this.socket);
  final _FakeSocket socket;

  @override
  Future<RealtimeSocket> connect(Uri uri) async => socket;
}

class _FakeSocket implements RealtimeSocket {
  final _messages = StreamController<Object?>();

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> send(Object message) async {
    if (message.toString().contains('"authenticate"')) {
      Future.delayed(Duration.zero, () => _messages.add('{"type":"ready"}'));
    }
  }

  void emitProjection({required String status, required int sequence}) {
    _messages.add(
      '{"type":"booking.projection-updated.v1","data":{'
      '"bookingId":"22222222-2222-4222-8222-222222222222",'
      '"status":"$status","sequence":$sequence}}',
    );
  }

  @override
  Future<void> close() => _messages.close();
}

class _Transport implements ApiTransport {
  _Transport({this.history = false, this.activeBooking = false});
  final bool history;
  final bool activeBooking;
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
    if (activeBooking) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'bookings': [
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
              'status': 'REQUESTED',
              'description': 'Kitchen sink is leaking underneath.',
              'createdAt': '2026-09-08T09:00:00.000Z',
              'version': 1,
              'locationLat': 17.385,
              'locationLng': 78.4867,
              'scheduledAt': '2026-09-09T10:00:00.000Z',
            },
          ],
          'nextCursor': null,
        },
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
