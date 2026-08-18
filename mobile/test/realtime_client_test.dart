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

  test('exposes provider presence, consent, and location commands', () async {
    final socket = _FakeSocket();
    final client = RealtimeClient(
      uri: Uri.parse('ws://localhost/realtime'),
      accessToken: () async => 'access-token',
      connector: _FakeConnector(socket),
    );
    await client.subscribeBooking('booking-1');
    await client.sendPresence(true);
    await client.sendLocationConsent(
      bookingId: 'booking-1',
      granted: true,
      noticeVersion: '2026-08-13',
    );
    await client.sendLocation(
      bookingId: 'booking-1',
      sequence: 1,
      capturedAt: DateTime.utc(2026, 8, 14),
      latitude: 22.3,
      longitude: 73.1,
      accuracyMeters: 10,
    );
    expect(socket.sent, hasLength(5));
    expect(jsonDecode(socket.sent[2])['type'], 'presence-update');
    expect(jsonDecode(socket.sent[3])['type'], 'location-consent');
    expect(jsonDecode(socket.sent[4])['type'], 'location-update');
    client.dispose();
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
  final sent = <String>[];

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> send(Object message) async {
    sent.add(message.toString());
    if (message.toString().contains('"authenticate"')) {
      Future.delayed(Duration.zero, () => emit({'type': 'ready'}));
    }
  }

  void emit(Map<String, Object?> message) => _messages.add(jsonEncode(message));

  @override
  Future<void> close() => _messages.close();
}
