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
    Duration pongTimeout = const Duration(seconds: 5),
    void Function(RealtimeClient)? onDispose,
  }) : _connector = connector ?? const ChannelRealtimeSocketConnector(),
       _pongTimeout = pongTimeout,
       _onDispose = onDispose;

  final Uri uri;
  final Future<String?> Function() accessToken;
  final RealtimeSocketConnector _connector;

  /// PERF-005. Called once from [dispose] so an owner can keep a set of live
  /// clients without having to guess when one goes away. The app creates a client
  /// per feature and per booking-tracking screen, and every one of them has to be
  /// revalidated on resume - a set the app forgets to prune would probe sockets
  /// that no longer exist, forever.
  final void Function(RealtimeClient)? _onDispose;

  /// PERF-005. How long to wait for a `pong` before declaring the socket dead.
  /// Mirrors REALTIME_PONG_TIMEOUT_MS on the gateway; injectable so a test does
  /// not have to spend five seconds proving a reconnect.
  final Duration _pongTimeout;
  final _projections = StreamController<RealtimeProjection>.broadcast();
  final _notifications = StreamController<RealtimeProjection>.broadcast();
  final _voiceFrames = StreamController<Map<String, Object?>>.broadcast();
  RealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  bool _closed = false;
  int _retries = 0;
  int _requestSequence = 0;
  Completer<void>? _readyCompleter;
  final Map<String, Completer<void>> _pendingAcks = {};
  final Set<String> _pendingSubscriptionAcks = {};
  final List<Map<String, String>> _subscriptions = [];

  /// PERF-005. When the last frame of any kind arrived from the server.
  ///
  /// Null until the first frame. Not the same question as [_lastProbeAt], which
  /// answers "did the server respond to us"; this answers "has the server said
  /// anything", which is the only thing that can prove we are not looking at a
  /// frozen snapshot.
  DateTime? _lastFrameAt;

  /// PERF-005. When a liveness probe was last answered.
  DateTime? _lastProbeAt;

  /// Set while we know the socket may be serving stale data. Drives the
  /// "may be out of date" affordance rather than being a diagnostic.
  bool _stale = false;

  Stream<RealtimeProjection> get projections => _projections.stream;
  Stream<RealtimeProjection> get notifications => _notifications.stream;
  Stream<Map<String, Object?>> get voiceFrames => _voiceFrames.stream;
  bool get isConnected =>
      _socket != null && (_readyCompleter?.isCompleted ?? false);

  /// PERF-005. Whether what the UI is showing can be trusted as current.
  ///
  /// Deliberately not the negation of [isConnected]. A socket can be open, the
  /// handshake can have completed, and the display can still be minutes old -
  /// that is exactly the state a frozen app wakes up in, because the close that
  /// killed the connection happened while we were asleep and has not been
  /// observed yet. Collapsing the two would have made this read `false` there.
  bool get isStale => _stale;

  /// When the last frame arrived, for the "updated N ago" affordance.
  DateTime? get lastFrameAt => _lastFrameAt;

  /// PERF-005. When the server last confirmed this session was still live.
  ///
  /// Distinct from [lastFrameAt]: a socket can be answered perfectly while no
  /// booking events are happening, so "nothing has arrived" is not evidence of a
  /// problem - but "we asked and nobody answered" is.
  DateTime? get lastProbeAt => _lastProbeAt;

  Future<void> subscribeBooking(String bookingId) async {
    _closed = false;
    _rememberSubscription('booking', bookingId);
    if (_socket != null) {
      await _subscribe('booking', bookingId);
      return;
    }
    await _connect();
  }

  Future<void> subscribeAccount(String userId) async {
    _closed = false;
    _rememberSubscription('account', userId);
    if (_socket != null) {
      await _subscribe('account', userId);
      return;
    }
    await _connect();
  }

  Future<void> connect() => _connect();

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

  Future<void> sendVoiceFrame({
    required String bookingId,
    required String callId,
    required String base64Data,
  }) => _send({
    'type': 'call.voice-frame.v1',
    'bookingId': bookingId,
    'callId': callId,
    'data': base64Data,
  });

  void _rememberSubscription(String channel, String resourceId) {
    final exists = _subscriptions.any(
      (subscription) =>
          subscription['channel'] == channel &&
          subscription['resourceId'] == resourceId,
    );
    if (!exists) {
      _subscriptions.add({'channel': channel, 'resourceId': resourceId});
    }
  }

  Future<void> _subscribe(String channel, String resourceId) async {
    final requestId = 'mobile-${++_requestSequence}';
    final acknowledgement = Completer<void>();
    _pendingAcks[requestId] = acknowledgement;
    _pendingSubscriptionAcks.add(requestId);
    try {
      await _send({
        'type': 'subscribe',
        'channel': channel,
        'resourceId': resourceId,
        'requestId': requestId,
      });
      try {
        await acknowledgement.future.timeout(const Duration(milliseconds: 250));
      } on TimeoutException {
        return;
      }
    } finally {
      _pendingAcks.remove(requestId);
      _pendingSubscriptionAcks.remove(requestId);
    }
  }

  Future<void> _restoreSubscriptions() async {
    for (final subscription in List<Map<String, String>>.from(_subscriptions)) {
      await _subscribe(subscription['channel']!, subscription['resourceId']!);
    }
  }

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
      await _restoreSubscriptions();
      // PERF-005. A completed handshake plus a replayed subscription list is the
      // point at which the display is genuinely current again, so staleness ends
      // here rather than on the next frame - which for a quiet booking could be
      // never.
      if (_stale) {
        _stale = false;
        notifyListeners();
      }
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    // PERF-005. Any frame at all is evidence the server is serving this session,
    // so it clears staleness. Counting only projections would have left a quiet
    // booking looking stale precisely when nothing was happening.
    _lastFrameAt = DateTime.now();
    if (_stale) {
      _stale = false;
      notifyListeners();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      if (decoded['type'] == 'ready') {
        if (_readyCompleter?.isCompleted == false) {
          _readyCompleter!.complete();
        }
      }
      if (decoded['type'] == 'pong') {
        _lastProbeAt = DateTime.now();
      }
      _completeAcknowledgement(decoded);
      final msgType = decoded['type']?.toString();
      if (msgType == 'call.voice-frame.v1') {
        _voiceFrames.add(Map<String, Object?>.from(decoded));
      } else if (msgType == 'notification.created.v1') {
        final data = decoded['data'];
        if (data is Map) {
          _notifications.add(
            RealtimeProjection(Map<String, Object?>.from(data)),
          );
        }
      } else if (msgType == 'booking.projection-updated.v1') {
        final data = decoded['data'];
        if (data is Map) {
          _projections.add(RealtimeProjection(Map<String, Object?>.from(data)));
        }
      } else if (msgType != null &&
          (msgType.startsWith('call.') || msgType.startsWith('chat.'))) {
        _projections.add(
          RealtimeProjection({
            'type': msgType,
            'data': decoded['data'],
            'resourceId': decoded['resourceId'],
          }),
        );
      }
    } on Object {
      // Malformed frames are ignored; the authoritative HTTP snapshot remains available.
    }
  }

  void _handleDisconnect() {
    if (_closed) return;
    _socket = null;
    // PERF-005. A dropped socket means anything already on screen is now a
    // snapshot of a moment that has passed, so staleness is set here rather than
    // only on resume. Waiting for a resume event would leave a user who simply
    // loses signal in a tunnel looking at a confident, wrong, unlabelled screen.
    _markStale();
    if (_readyCompleter?.isCompleted == false) {
      _readyCompleter!.completeError(Exception('Disconnected'));
    }
    notifyListeners();
    final delay = Duration(milliseconds: 500 * (1 << _retries.clamp(0, 4)));
    _retries += 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_connect()));
  }

  void _markStale() {
    if (_stale) return;
    _stale = true;
  }

  /// PERF-005. Re-establish the socket after the app returns to the foreground.
  ///
  /// Why this cannot be left to the retry timer: while the app is suspended the
  /// Dart isolate is frozen, so it neither answers the gateway's protocol ping
  /// nor observes the close that follows. By the time [revalidateOnResume] runs,
  /// the server has usually already terminated this socket, the close has not
  /// been read, [isConnected] is `true`, and no timer is pending - because the
  /// timer is only created by [_handleDisconnect], which is exactly the code that
  /// has not run. The app is now confident, connected, and wrong.
  ///
  /// So the resume asks the server directly. A `pong` proves the session is still
  /// being served and costs one frame; no `pong` means the socket is gone and the
  /// client tears it down and reconnects on the normal path. Anything already on
  /// screen is marked stale first, because we cannot prove it is current until the
  /// probe comes back, and it usually is not.
  ///
  /// Returns true if the socket was confirmed live.
  Future<bool> revalidateOnResume() async {
    if (_closed) return false;
    _markStale();
    notifyListeners();

    if (_socket == null) {
      // Already known down, or never up. A pending backoff would otherwise make
      // the user wait out a delay computed while the app was frozen.
      _retryTimer?.cancel();
      _retryTimer = null;
      await _connect();
      return isConnected;
    }

    final requestId = 'probe-${++_requestSequence}';
    final answered = Completer<void>();
    _pendingAcks[requestId] = answered;
    try {
      final socket = _socket;
      if (socket == null) return false;
      await socket.send(jsonEncode({'type': 'ping', 'requestId': requestId}));
      await answered.future.timeout(_pongTimeout);
      return true;
    } on Object {
      // No pong. The socket is not being served, whatever `isConnected` says.
      await _forceReconnect();
      return false;
    } finally {
      _pendingAcks.remove(requestId);
    }
  }

  /// Drops the current socket without waiting for a close we may never observe,
  /// then reconnects. Used when a probe has already proven it is dead, so going
  /// through [_handleDisconnect] would double the backoff for a failure the
  /// client has just diagnosed itself.
  Future<void> _forceReconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } on Object {
        // The server has almost certainly already closed it; nothing to do.
      }
    }
    if (_readyCompleter?.isCompleted == false) {
      _readyCompleter!.completeError(Exception('Replaced'));
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _retries = 0;
    await _connect();
  }

  Future<void> _send(Map<String, Object?> message) async {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    await socket.send(jsonEncode(message));
  }

  Future<void> _sendWithAck(Map<String, Object?> message) async {
    if (_socket == null) {
      await _connect();
      if (_socket == null) {
        throw StateError('offline');
      }
    }
    if (_readyCompleter?.isCompleted == false) {
      try {
        await _readyCompleter!.future.timeout(const Duration(seconds: 3));
      } catch (_) {
        throw StateError('offline');
      }
    }
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
        type == 'location-ack' ||
        // PERF-005. The liveness probe's own acknowledgement. Without it here
        // the probe can never succeed, because this allow-list is what decides
        // which frames count as an answer - and a probe that always times out
        // looks exactly like a dead socket, so it would have torn down healthy
        // connections on every resume.
        type == 'pong' ||
        (type == 'subscribed' &&
            _pendingSubscriptionAcks.contains(requestId))) {
      acknowledgement.complete();
    } else if (type == 'location-denied' ||
        type == 'subscription-denied' ||
        type == 'error') {
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
    unawaited(_notifications.close());
    unawaited(_voiceFrames.close());
    for (final acknowledgement in _pendingAcks.values) {
      if (!acknowledgement.isCompleted) {
        acknowledgement.complete();
      }
    }
    _pendingAcks.clear();
    _pendingSubscriptionAcks.clear();
    super.dispose();
    // After super.dispose(): the owner must not be able to probe a dead client,
    // and a listener callback during dispose would be re-entrant.
    _onDispose?.call(this);
  }
}

Uri realtimeUriFromApi(Uri apiUri) => apiUri.replace(
  scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
  path: '/realtime',
);
