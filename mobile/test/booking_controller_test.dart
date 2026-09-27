import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
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

  test('sends cart line items and parses server-computed pricing', () async {
    final transport = _Transport(withItems: true);
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );

    await controller.create(
      serviceCategoryId: '11111111-1111-4111-8111-111111111111',
      description: 'Kitchen sink is leaking underneath.',
      latitude: 17.385,
      longitude: 78.4867,
      items: const [
        // Only the catalogue entry and quantity are sent; the server prices it
        // (SEC-001).
        BookingItemDraft(subServiceId: 'plumb-3', quantity: 2),
      ],
    );

    expect(transport.requests.single.body?['items'], [
      {
        'subServiceId': 'plumb-3',
        'quantity': 2,
      },
    ]);
    final booking = controller.bookings.single;
    expect(booking.items?.single.lineTotalMinor, 49800);
    expect(booking.pricing?.totalMinor, 58764);
    expect(booking.estimatedDurationMinutes, 90);
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
    expect(
      controller.acceptedBooking.value,
      '22222222-2222-4222-8222-222222222222',
    );
    expect(controller.bookings.single.status, 'ASSIGNED');
    // Projection rebuilds must carry forward location and schedule fields.
    expect(controller.bookings.single.locationLatitude, 17.385);
    expect(controller.bookings.single.locationLongitude, 78.4867);
    expect(controller.bookings.single.scheduledAt, isNotNull);

    // One-shot: later transitions do not re-fire.
    socket.emitProjection(status: 'EN_ROUTE', sequence: 3);
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.acceptedBooking.value,
      '22222222-2222-4222-8222-222222222222',
    );

    controller.dispose();
  });

  // Regression: the projection carried items but not the total, so after a
  // provider raised the price the customer saw the new line list next to the
  // old "Total (incl. GST)" until the next 5s poll.
  test(
    'an on-site price increase updates items and total in the same frame',
    () async {
      final socket = _FakeSocket();
      final controller = BookingController(
        BookingRepository(
          api: _Transport(activeBooking: true, withExistingPricing: true),
          accessToken: () async => 'token',
        ),
        realtime: RealtimeClient(
          uri: Uri.parse('wss://realtime.example.test/socket'),
          accessToken: () async => 'token',
          connector: _FakeConnector(socket),
        ),
      );

      await controller.load();
      await controller.startRealtime();
      await Future<void>.delayed(Duration.zero);

      expect(controller.bookings.single.pricing?.totalMinor, 24900);
      expect(controller.bookings.single.items?.single.quantity, 1);

      // Provider raises 249.00 to 500.00: subtotal 50000, +18% GST = 59000.
      socket.emitPriceAdjustment(
        sequence: 2,
        unitPriceMinor: 50000,
        subtotalMinor: 50000,
        totalMinor: 59000,
      );
      await Future<void>.delayed(Duration.zero);

      final booking = controller.bookings.single;
      expect(booking.items?.single.unitPriceMinor, 50000);
      expect(booking.pricing?.subtotalMinor, 50000);
      expect(booking.pricing?.totalMinor, 59000);
      expect(booking.pricing?.formattedTotal, '₹590');
      expect(booking.status, 'IN_PROGRESS');

      controller.dispose();
    },
  );

  test(
    'an unparseable total is ignored instead of tearing down the stream',
    () async {
      final socket = _FakeSocket();
      final controller = BookingController(
        BookingRepository(
          api: _Transport(activeBooking: true, withExistingPricing: true),
          accessToken: () async => 'token',
        ),
        realtime: RealtimeClient(
          uri: Uri.parse('wss://realtime.example.test/socket'),
          accessToken: () async => 'token',
          connector: _FakeConnector(socket),
        ),
      );

      await controller.load();
      await controller.startRealtime();
      await Future<void>.delayed(Duration.zero);

      socket.emit(
        '{"type":"booking.projection-updated.v1","data":{'
        '"bookingId":"22222222-2222-4222-8222-222222222222",'
        '"status":"IN_PROGRESS","sequence":2,"pricing":{"totalMinor":"oops"}}}',
      );
      await Future<void>.delayed(Duration.zero);

      // The last known good total survives and the stream is still alive.
      expect(controller.bookings.single.pricing?.totalMinor, 24900);
      expect(controller.bookings.single.status, 'IN_PROGRESS');

      socket.emitProjection(status: 'COMPLETED', sequence: 3);
      await Future<void>.delayed(Duration.zero);
      expect(controller.bookings.single.status, 'COMPLETED');

      controller.dispose();
    },
  );

  test('create returns CustomerBooking', () async {
    final controller = BookingController(
      BookingRepository(api: _Transport(), accessToken: () async => 'token'),
    );

    final booking = await controller.create(
      serviceCategoryId: '11111111-1111-4111-8111-111111111111',
      description: 'Kitchen sink is leaking underneath.',
      latitude: 17.385,
      longitude: 78.4867,
    );

    expect(booking.id, '22222222-2222-4222-8222-222222222222');
    expect(booking.status, 'REQUESTED');
    expect(controller.bookings.first.id, booking.id);
    controller.dispose();
  });

  test('load fires acceptedBooking when REQUESTED becomes ASSIGNED', () async {
    var responseStatus = 'REQUESTED';
    final transport = _DynamicTransport(getStatus: () => responseStatus);
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );

    await controller.load();
    expect(controller.bookings.single.status, 'REQUESTED');
    expect(controller.acceptedBooking.value, isNull);

    // Provider accepts, next load/poll catches it:
    responseStatus = 'ASSIGNED';
    await controller.load();
    expect(controller.bookings.single.status, 'ASSIGNED');
    expect(
      controller.acceptedBooking.value,
      '22222222-2222-4222-8222-222222222222',
    );

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

  void emit(String message) => _messages.add(message);

  void emitProjection({required String status, required int sequence}) {
    _messages.add(
      '{"type":"booking.projection-updated.v1","data":{'
      '"bookingId":"22222222-2222-4222-8222-222222222222",'
      '"status":"$status","sequence":$sequence}}',
    );
  }

  /// An on-site price adjustment: the provider raised the line and the server
  /// recomputed the total. Both ride the same frame on purpose.
  void emitPriceAdjustment({
    required int sequence,
    required int unitPriceMinor,
    required int subtotalMinor,
    required int totalMinor,
  }) {
    _messages.add(
      '{"type":"booking.projection-updated.v1","data":{'
      '"bookingId":"22222222-2222-4222-8222-222222222222",'
      '"status":"IN_PROGRESS","sequence":$sequence,'
      '"items":[{"id":"plumb-3","name":"Shower & Water Pipe Leakage",'
      '"quantity":1,"unitPriceMinor":$unitPriceMinor}],'
      '"pricing":{"subtotalMinor":$subtotalMinor,"gstMinor":0,'
      '"totalMinor":$totalMinor,"currency":"INR"}}}',
    );
  }

  @override
  Future<void> close() => _messages.close();
}

class _Transport implements ApiTransport {
  _Transport({
    this.history = false,
    this.activeBooking = false,
    this.withItems = false,
    this.withExistingPricing = false,
  });
  final bool history;
  final bool activeBooking;
  final bool withItems;
  final bool withExistingPricing;
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
    if (activeBooking && withExistingPricing) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'bookings': [
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
              'status': 'IN_PROGRESS',
              'description': 'Kitchen sink is leaking underneath.',
              'createdAt': '2026-09-08T09:00:00.000Z',
              'version': 1,
              'locationLat': 17.385,
              'locationLng': 78.4867,
              'items': [
                {
                  'id': 'plumb-3',
                  'name': 'Shower & Water Pipe Leakage',
                  'quantity': 1,
                  'unitPriceMinor': 24900,
                },
              ],
              'pricing': {
                'subtotalMinor': 24900,
                'gstMinor': 0,
                'totalMinor': 24900,
                'currency': 'INR',
              },
            },
          ],
          'nextCursor': null,
        },
      );
    }
    if (withItems) {
      return const ApiResponse(
        statusCode: 201,
        body: {
          'booking': {
            'id': '22222222-2222-4222-8222-222222222222',
            'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
            'status': 'REQUESTED',
            'description': 'Kitchen sink is leaking underneath.',
            'createdAt': '2026-08-13T12:00:00.000Z',
            'items': [
              {
                'id': 'plumb-3',
                'name': 'Shower & Water Pipe Leakage',
                'quantity': 2,
                'unitPriceMinor': 24900,
                'durationMinutes': 45,
              },
            ],
            'pricing': {
              'subtotalMinor': 49800,
              'gstMinor': 8964,
              'totalMinor': 58764,
              'currency': 'INR',
            },
            'estimatedDurationMinutes': 90,
          },
        },
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

class _DynamicTransport implements ApiTransport {
  _DynamicTransport({required this.getStatus});
  final String Function() getStatus;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return ApiResponse(
      statusCode: 200,
      body: {
        'bookings': [
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'serviceCategoryId': '11111111-1111-4111-8111-111111111111',
            'status': getStatus(),
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
}
