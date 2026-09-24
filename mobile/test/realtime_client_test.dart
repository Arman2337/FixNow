import 'dart:async';
import 'dart:convert';

import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authenticates, subscribes, and publishes booking projections',
    () async {
      final socket = _FakeSocket();
      final client = RealtimeClient(
        uri: Uri.parse('ws://localhost/realtime'),
        accessToken: () async => 'access-token',
        connector: _FakeConnector(socket),
      );
      final projection = expectLater(
        client.projections,
        emits(isA<RealtimeProjection>()),
      );

      await client.subscribeBooking('booking-1');
      expect(jsonDecode(socket.sent.first)['type'], 'authenticate');
      final subscribe = jsonDecode(socket.sent[1]) as Map<String, dynamic>;
      expect(subscribe, containsPair('resourceId', 'booking-1'));
      socket.emit({
        'type': 'booking.projection-updated.v1',
        'data': {
          'bookingId': 'booking-1',
          'status': 'EN_ROUTE',
          'sequence': 2,
          'locationAvailability': 'live',
        },
      });
      await projection;
      client.dispose();
    },
  );

  test('waits for subscription acknowledgement and restores account subscriptions', () async {
    final firstSocket = _FakeSocket();
    final secondSocket = _FakeSocket();
    final sockets = <_FakeSocket>[firstSocket, secondSocket];
    var connection = 0;
    final client = RealtimeClient(
      uri: Uri.parse('ws://localhost/realtime'),
      accessToken: () async => 'access-token',
      connector: _Connector(() => sockets[connection++]),
    );

    final accountSubscription = client.subscribeAccount('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final firstSubscribe = jsonDecode(firstSocket.sent[1]) as Map<String, dynamic>;
    expect(firstSubscribe['requestId'], isNotNull);
    firstSocket.emit({
      'type': 'subscribed',
      'requestId': firstSubscribe['requestId'],
      'channel': 'account',
      'resourceId': 'user-1',
    });
    await accountSubscription;

    await firstSocket.close();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(secondSocket.sent.map(jsonDecode), contains(
      isA<Map<String, dynamic>>().having(
        (message) => message['type'],
        'type',
        'subscribe',
      ).having((message) => message['resourceId'], 'resourceId', 'user-1'),
    ));
    client.dispose();
  });

  test('emits account notification projections', () async {
    final socket = _FakeSocket();
    final client = RealtimeClient(
      uri: Uri.parse('ws://localhost/realtime'),
      accessToken: () async => 'access-token',
      connector: _FakeConnector(socket),
    );
    final notification = expectLater(
      client.notifications,
      emits(
        isA<RealtimeProjection>().having(
          (projection) => projection.data['id'],
          'id',
          'notification-1',
        ),
      ),
    );

    await client.subscribeAccount('user-1');
    await Future<void>.delayed(Duration.zero);
    final subscribe = jsonDecode(socket.sent[1]) as Map<String, dynamic>;
    socket.emit({
      'type': 'subscribed',
      'requestId': subscribe['requestId'],
      'channel': 'account',
      'resourceId': 'user-1',
    });
    socket.emit({
      'type': 'notification.created.v1',
      'data': {
        'id': 'notification-1',
        'title': 'Booking update',
        'body': 'Your booking changed.',
        'category': 'bookings',
        'timestamp': '2026-09-24T10:00:00.000Z',
        'isRead': false,
      },
    });

    await notification;
    client.dispose();
  });

  test('exposes provider presence, consent, and location commands', () async {
    final socket = _FakeSocket();
    final client = RealtimeClient(
      uri: Uri.parse('ws://localhost/realtime'),
      accessToken: () async => 'access-token',
      connector: _FakeConnector(socket),
    );
    await client.subscribeBooking('booking-1');
    final presence = client.sendPresence(true);
    socket.emit({
      'type': 'presence-ack',
      'requestId': (jsonDecode(socket.sent[2]) as Map)['requestId'],
    });
    await presence;
    final consent = client.sendLocationConsent(
      bookingId: 'booking-1',
      granted: true,
      noticeVersion: '2026-08-13',
    );
    socket.emit({
      'type': 'location-consent-ack',
      'requestId': (jsonDecode(socket.sent[3]) as Map)['requestId'],
    });
    await consent;
    final location = client.sendLocation(
      bookingId: 'booking-1',
      sequence: 1,
      capturedAt: DateTime.utc(2026, 8, 14),
      latitude: 22.3,
      longitude: 73.1,
      accuracyMeters: 10,
    );
    socket.emit({
      'type': 'location-ack',
      'requestId': (jsonDecode(socket.sent[4]) as Map)['requestId'],
    });
    await location;
    expect(socket.sent, hasLength(5));
    expect(jsonDecode(socket.sent[2])['type'], 'presence-update');
    expect(jsonDecode(socket.sent[3])['type'], 'location-consent');
    expect(jsonDecode(socket.sent[4])['type'], 'location-update');
    client.dispose();
  });
}

class _Connector implements RealtimeSocketConnector {
  _Connector(this.factory);

  final _FakeSocket Function() factory;

  @override
  Future<RealtimeSocket> connect(Uri uri) async => factory();
}

class _FakeConnector implements RealtimeSocketConnector {
  _FakeConnector(this.socket);
  final _FakeSocket socket;

  @override
  Future<RealtimeSocket> connect(Uri uri) async => socket;
}

class _FakeSocket implements RealtimeSocket {
  final _messages = StreamController<Object?>();
  final sent = <String>[];

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> send(Object message) async {
    sent.add(message.toString());
    final value = jsonDecode(message.toString()) as Map<String, dynamic>;
    if (value['type'] == 'authenticate') {
      Future.delayed(Duration.zero, () => emit({'type': 'ready'}));
    } else if (value['type'] == 'subscribe') {
      Future.delayed(Duration.zero, () => emit({
            'type': 'subscribed',
            'requestId': value['requestId'],
            'channel': value['channel'],
            'resourceId': value['resourceId'],
          }));
    }
  }

  void emit(Map<String, Object?> message) => _messages.add(jsonEncode(message));

  @override
  Future<void> close() => _messages.close();
}
