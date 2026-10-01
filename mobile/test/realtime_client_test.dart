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

  test(
    'waits for subscription acknowledgement and restores account subscriptions',
    () async {
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
      final firstSubscribe =
          jsonDecode(firstSocket.sent[1]) as Map<String, dynamic>;
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
      expect(
        secondSocket.sent.map(jsonDecode),
        contains(
          isA<Map<String, dynamic>>()
              .having((message) => message['type'], 'type', 'subscribe')
              .having(
                (message) => message['resourceId'],
                'resourceId',
                'user-1',
              ),
        ),
      );
      client.dispose();
    },
  );

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

  // PERF-005. The resume path.
  group('revalidateOnResume', () {
    RealtimeClient build({
      required RealtimeSocketConnector connector,
      Duration pongTimeout = const Duration(milliseconds: 60),
    }) => RealtimeClient(
      uri: Uri.parse('ws://localhost/realtime'),
      accessToken: () async => 'access-token',
      connector: connector,
      pongTimeout: pongTimeout,
    );

    test(
      'a socket the server still serves is confirmed without reconnecting',
      () async {
        // The important property: a healthy socket must NOT be torn down. A fix
        // that reconnected unconditionally would pass every other test here and
        // still make every app resume cost a handshake plus a replay of every
        // subscription.
        final socket = _FakeSocket(answersPing: true);
        final client = build(connector: _FakeConnector(socket));
        await client.subscribeAccount('user-1');
        final connectionsBefore = socket.sent
            .where((frame) => jsonDecode(frame)['type'] == 'authenticate')
            .length;

        expect(await client.revalidateOnResume(), isTrue);

        expect(
          socket.sent
              .where((frame) => jsonDecode(frame)['type'] == 'authenticate')
              .length,
          connectionsBefore,
        );
        expect(client.isConnected, isTrue);
        client.dispose();
      },
    );

    test(
      'a silent socket is declared stale, torn down and reconnected',
      () async {
        // This is the actual bug: a frozen app cannot answer the gateway's
        // protocol ping, the gateway terminates the socket, the client never
        // observes the close - so isConnected is still true and nothing will ever
        // correct it. Only a probe catches it.
        final sockets = <_FakeSocket>[
          _FakeSocket(answersPing: false),
          _FakeSocket(answersPing: true),
        ];
        var connection = 0;
        final client = build(
          connector: _Connector(() => sockets[connection++]),
        );
        await client.subscribeAccount('user-1');
        expect(client.isConnected, isTrue);

        expect(await client.revalidateOnResume(), isFalse);

        expect(connection, 2, reason: 'a dead socket must be replaced');
        expect(client.isConnected, isTrue);
        client.dispose();
      },
    );

    test('marks the display stale while the probe is unanswered', () async {
      // The user-facing half. A screen that may be showing an old booking has to
      // say so before the probe comes back, not after - the wait is the whole
      // period during which the data is untrustworthy.
      //
      // Two sockets, because a timed-out probe goes on to reconnect and a
      // connector that kept handing back the socket it had just closed would be
      // testing the fake rather than the client.
      final sockets = <_FakeSocket>[
        _FakeSocket(answersPing: false),
        _FakeSocket(answersPing: true),
      ];
      var connection = 0;
      final client = build(
        connector: _Connector(() => sockets[connection++]),
        pongTimeout: const Duration(milliseconds: 200),
      );
      await client.subscribeAccount('user-1');
      expect(client.isStale, isFalse);

      final probe = client.revalidateOnResume();
      expect(client.isStale, isTrue, reason: 'set before awaiting the pong');
      await probe;
      client.dispose();
    });

    test('staleness clears once the socket is genuinely live again', () async {
      final sockets = <_FakeSocket>[
        _FakeSocket(answersPing: false),
        _FakeSocket(answersPing: true),
      ];
      var connection = 0;
      final client = build(connector: _Connector(() => sockets[connection++]));
      await client.subscribeAccount('user-1');

      await client.revalidateOnResume();
      expect(client.isStale, isFalse);
      client.dispose();
    });

    test(
      'a frame of any kind clears staleness, not just projections',
      () async {
        // Only counting projections would leave a quiet booking looking stale
        // exactly when nothing was happening - which is most of the time.
        final socket = _FakeSocket(answersPing: true);
        final client = build(connector: _FakeConnector(socket));
        await client.subscribeAccount('user-1');
        final probe = client.revalidateOnResume();
        socket.emit({'type': 'notification.created.v1', 'data': {}});
        await probe;
        expect(client.isStale, isFalse);
        client.dispose();
      },
    );

    test('a dropped socket is stale even without a resume', () async {
      // Somebody in a tunnel is not resuming from suspension, and must not be
      // left looking at a confident, wrong, unlabelled screen.
      final socket = _FakeSocket(answersPing: true);
      final client = build(connector: _FakeConnector(socket));
      await client.subscribeAccount('user-1');
      expect(client.isStale, isFalse);

      await socket.simulateServerClose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.isStale, isTrue);
      client.dispose();
    });

    test('an already-dead socket skips the backoff delay on resume', () async {
      // The retry timer was scheduled while the app was frozen. Waiting it out
      // means the user opens the app to a dead dashboard and then watches it
      // sit there for up to eight seconds.
      final sockets = <_FakeSocket>[
        _FakeSocket(answersPing: true),
        _FakeSocket(answersPing: true),
      ];
      var connection = 0;
      final client = build(connector: _Connector(() => sockets[connection++]));
      await client.subscribeAccount('user-1');

      // Simulate the frozen state: the socket is gone and a backoff is pending.
      await sockets.first.simulateServerClose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final watch = Stopwatch()..start();
      await client.revalidateOnResume();
      watch.stop();

      expect(client.isConnected, isTrue);
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 300)));
      client.dispose();
    });
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
  _FakeSocket({this.answersPing = false});

  /// PERF-005. Whether this socket behaves like a live server or like one that
  /// was terminated while the client was suspended. Defaults to silent so the
  /// pre-existing tests keep describing a socket that never answers anything.
  final bool answersPing;

  final _messages = StreamController<Object?>();
  final sent = <String>[];

  /// PERF-005. Stands in for the gateway terminating this socket while the
  /// client was suspended: the stream ends, and the client learns about it only
  /// when it is looking.
  Future<void> simulateServerClose() async {
    if (!_messages.isClosed) await _messages.close();
  }

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> send(Object message) async {
    sent.add(message.toString());
    final value = jsonDecode(message.toString()) as Map<String, dynamic>;
    if (value['type'] == 'authenticate') {
      Future.delayed(Duration.zero, () => emit({'type': 'ready'}));
    } else if (value['type'] == 'subscribe') {
      Future.delayed(
        Duration.zero,
        () => emit({
          'type': 'subscribed',
          'requestId': value['requestId'],
          'channel': value['channel'],
          'resourceId': value['resourceId'],
        }),
      );
    } else if (value['type'] == 'ping' && answersPing) {
      Future.delayed(
        Duration.zero,
        () => emit({
          'type': 'pong',
          'requestId': value['requestId'],
          'serverTime': 1,
        }),
      );
    }
  }

  void emit(Map<String, Object?> message) => _messages.add(jsonEncode(message));

  @override
  Future<void> close() async {
    if (!_messages.isClosed) await _messages.close();
  }
}
