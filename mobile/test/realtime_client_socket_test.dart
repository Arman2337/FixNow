import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal stand-in for the backend realtime gateway: accepts one socket,
/// completes authentication with `ready`, echoes the booking subscription and
/// then pushes the exact `booking.projection-updated.v1` frame the gateway
/// emits after a provider location ingest.
Future<HttpServer> _startFakeGateway(int portBias) async {
  final server = await HttpServer.bind('127.0.0.1', portBias);
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    socket.add(
      jsonEncode({
        'type': 'ready',
        'connectionId': 'test-connection',
        'protocolVersion': 1,
      }),
    );
    socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, Object?>;
      if (message['type'] == 'authenticate') {
        // `ready` was already pushed above, mirroring the gateway's flow.
        return;
      }
      if (message['type'] == 'subscribe') {
        socket.add(
          jsonEncode({
            'type': 'subscribed',
            'requestId': message['requestId'],
            'subscriptionId': 'sub-1',
            'channel': message['channel'],
            'resourceId': message['resourceId'],
          }),
        );
        socket.add(
          jsonEncode({
            'type': 'booking.projection-updated.v1',
            'eventId': 'event-1',
            'subscriptionId': 'sub-1',
            'resourceId': 'booking-1',
            'sequence': 7,
            'occurredAt': '2026-09-18T09:00:01.000Z',
            'data': {
              'bookingId': 'booking-1',
              'status': 'EN_ROUTE',
              'sequence': 7,
              'occurredAt': '2026-09-18T09:00:01.000Z',
              'location': {
                'latitude': 23.0225,
                'longitude': 72.5714,
                'accuracyMeters': 12,
                'capturedAt': '2026-09-18T09:00:00.000Z',
                'receivedAt': '2026-09-18T09:00:01.000Z',
              },
              'locationAvailability': 'live',
              'eta': {
                'estimatedMinutes': 10,
                'calculatedAt': '2026-09-18T09:00:01.000Z',
                'source': 'openrouteservice-driving',
              },
              'route': {
                'distanceMeters': 4200,
                'durationSeconds': 600,
                'coordinates': [
                  [72.5714, 23.0225],
                  [72.5791, 23.0276],
                ],
              },
            },
          }),
        );
      }
    });
  });
  return server;
}

void main() {
  test(
    'real client receives and parses the provider journey projection over a live socket',
    () async {
      final server = await _startFakeGateway(47000 + DateTime.now().second * 3);
      addTearDown(() async {
        await server.close(force: true);
      });

      final client = RealtimeClient(
        uri: Uri.parse('ws://127.0.0.1:${server.port}'),
        accessToken: () async => 'token',
      );
      addTearDown(client.dispose);

      final projections = <RealtimeProjection>[];
      final subscription = client.projections.listen(projections.add);
      addTearDown(subscription.cancel);

      await client.subscribeBooking('booking-1');

      // The projection must arrive through the real connect → authenticate →
      // ready → subscribe → receive pipeline.
      await projectionReceived(projections);

      final data = projections.first.data;
      expect(data['bookingId'], 'booking-1');
      expect(data['locationAvailability'], 'live');
      expect(data['status'], 'EN_ROUTE');
      final location = data['location'] as Map<Object?, Object?>;
      expect(location['latitude'], 23.0225);
      expect(location['longitude'], 72.5714);
      expect(location['receivedAt'], '2026-09-18T09:00:01.000Z');
      final route = data['route'] as Map<Object?, Object?>;
      expect((route['coordinates'] as List).length, 2);
    },
  );
}

Future<void> projectionReceived(
  List<RealtimeProjection> projections,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (projections.isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('No booking projection arrived within 5s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
