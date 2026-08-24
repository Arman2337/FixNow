import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeProjection {
  const RealtimeProjection(this.data);
  final Map<String, Object?> data;
}

abstract interface class RealtimeSocket {
  Stream<Object?> get messages;
  Future<void> send(Object message);
  Future<void> close();
}

abstract interface class RealtimeSocketConnector {
  Future<RealtimeSocket> connect(Uri uri);
}

class ChannelRealtimeSocketConnector implements RealtimeSocketConnector {
  const ChannelRealtimeSocketConnector();

  @override
  Future<RealtimeSocket> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return _ChannelRealtimeSocket(channel);
  }
}

class _ChannelRealtimeSocket implements RealtimeSocket {
  _ChannelRealtimeSocket(this._channel);
  final WebSocketChannel _channel;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  Future<void> send(Object message) async => _channel.sink.add(message);

  @override
  Future<void> close() async => await _channel.sink.close();
}

class RealtimeClient extends ChangeNotifier {
  RealtimeClient({
    required this.uri,
    required this.accessToken,
    RealtimeSocketConnector? connector,
  }) : _connector = connector ?? const ChannelRealtimeSocketConnector();

  final Uri uri;
  final Future<String?> Function() accessToken;
  final RealtimeSocketConnector _connector;
  final _projections = StreamController<RealtimeProjection>.broadcast();
  RealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  String? _bookingId;
  bool _closed = false;
  int _retries = 0;
  int _requestSequence = 0;
  Completer<void>? _readyCompleter;
  final Map<String, Completer<void>> _pendingAcks = {};

  Stream<RealtimeProjection> get projections => _projections.stream;

  Future<void> subscribeBooking(String bookingId) async {
    if (_bookingId == bookingId && _socket != null) {
      if (_readyCompleter?.isCompleted == false) {
        try {
          await _readyCompleter!.future;
        } catch (_) {}
      }
      return;
    }
    _bookingId = bookingId;
    _closed = false;
    await _connect();
  }

  Future<void> sendPresence(bool online) =>
      _sendWithAck({'type': 'presence-update', 'online': online});

  Future<void> sendLocationConsent({
    required String bookingId,
    required bool granted,
    required String noticeVersion,
  }) => _sendWithAck({
    'type': 'location-consent',
    'bookingId': bookingId,
    'granted': granted,
    'noticeVersion': noticeVersion,
  });

  Future<void> sendLocation({
    required String bookingId,
    required int sequence,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) => _sendWithAck({
    'type': 'location-update',
    'bookingId': bookingId,
    'sequence': sequence,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
  });

  Future<void> _connect() async {
    _retryTimer?.cancel();
    final token = await accessToken();
    if (_closed || token == null) return;
    try {
      final socket = await _connector.connect(uri);
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _retries = 0;
      _readyCompleter = Completer<void>();
      await socket.send(
        jsonEncode({'type': 'authenticate', 'accessToken': token}),
      );
      _subscription = socket.messages.listen(
        _onMessage,
        onDone: () {
          _handleDisconnect();
        },
        onError: (_) {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
      notifyListeners();
      await _readyCompleter!.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      if (decoded['type'] == 'ready') {
        if (_readyCompleter?.isCompleted == false) {
          _readyCompleter!.complete();
        }
        if (_bookingId != null) {
          unawaited(
            _send({
              'type': 'subscribe',
              'channel': 'booking',
              'resourceId': _bookingId,
            }),
          );
        }
      }
      _completeAcknowledgement(decoded);
      if (decoded['type'] != 'booking.projection-updated.v1') return;
      final data = decoded['data'];
      if (data is Map) {
        _projections.add(RealtimeProjection(Map<String, Object?>.from(data)));
      }
    } on Object {
      // Malformed frames are ignored; the authoritative HTTP snapshot remains available.
    }
  }

  void _handleDisconnect() {
    if (_closed) return;
    _socket = null;
    if (_readyCompleter?.isCompleted == false) {
      _readyCompleter!.completeError(Exception('Disconnected'));
    }
    notifyListeners();
    final delay = Duration(milliseconds: 500 * (1 << _retries.clamp(0, 4)));
    _retries += 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_connect()));
  }

  Future<void> _send(Map<String, Object?> message) async {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    await socket.send(jsonEncode(message));
  }

  Future<void> _sendWithAck(Map<String, Object?> message) async {
    final requestId = 'mobile-${++_requestSequence}';
    final acknowledgement = Completer<void>();
    _pendingAcks[requestId] = acknowledgement;
    try {
      await _send({...message, 'requestId': requestId});
      await acknowledgement.future.timeout(const Duration(seconds: 5));
    } finally {
      _pendingAcks.remove(requestId);
    }
  }

  void _completeAcknowledgement(Map decoded) {
    final requestId = decoded['requestId'];
    if (requestId is! String) return;
    final acknowledgement = _pendingAcks[requestId];
    if (acknowledgement == null || acknowledgement.isCompleted) return;
    final type = decoded['type'];
    if (type == 'presence-ack' ||
        type == 'location-consent-ack' ||
        type == 'location-ack') {
      acknowledgement.complete();
    } else if (type == 'location-denied' || type == 'error') {
      acknowledgement.completeError(
        StateError(decoded['code']?.toString() ?? 'Realtime request denied'),
      );
    }
  }

  @override
  void dispose() {
    _closed = true;
    _retryTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    unawaited(_projections.close());
    for (final acknowledgement in _pendingAcks.values) {
      if (!acknowledgement.isCompleted) {
        acknowledgement.completeError(StateError('Realtime client closed'));
      }
    }
    _pendingAcks.clear();
    super.dispose();
  }
}

Uri realtimeUriFromApi(Uri apiUri) => apiUri.replace(
  scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
  path: '/realtime',
);
