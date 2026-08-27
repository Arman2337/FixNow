import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class CallController extends ChangeNotifier {
  CallController({
    required this.bookingId,
    required this.repository,
    this.realtimeClient,
    CallSession? initialSession,
    this.autoStart = true,
  }) : _currentSession = initialSession {
    if (autoStart && _currentSession == null) {
      startCall();
    } else if (_currentSession != null &&
        _currentSession!.status == CallStatus.connected) {
      _startDurationTicker();
    }
    _listenToRealtime();
  }

  final String bookingId;
  final CallRepository repository;
  final RealtimeClient? realtimeClient;
  final bool autoStart;

  CallSession? _currentSession;
  bool _isLoading = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _elapsedSeconds = 0;
  String? _errorMessage;
  Timer? _ticker;
  StreamSubscription<RealtimeProjection>? _socketSub;

  CallSession? get currentSession => _currentSession;
  CallStatus get status => _currentSession?.status ?? CallStatus.initiated;
  bool get isLoading => _isLoading;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  int get elapsedSeconds => _elapsedSeconds;
  String? get errorMessage => _errorMessage;

  String get formattedDuration {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _listenToRealtime() {
    if (realtimeClient == null) return;
    _socketSub = realtimeClient!.projections.listen((projection) {
      final type = projection.data['type']?.toString();
      final data = projection.data['data'];
      if (data is! Map) return;

      final incomingBookingId = data['bookingId']?.toString();
      if (incomingBookingId != bookingId) return;

      if (type == 'call.answered.v1') {
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _startDurationTicker();
        notifyListeners();
      } else if (type == 'call.rejected.v1') {
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _stopDurationTicker();
        notifyListeners();
      } else if (type == 'call.ended.v1') {
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _stopDurationTicker();
        notifyListeners();
      }
    });
  }

  Future<void> startCall() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await repository.initiateCall(bookingId);
      _currentSession = session;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not place audio call. Please check connection.';
      _currentSession = _currentSession?.copyWith(status: CallStatus.failed) ??
          CallSession(
            id: 'failed',
            bookingId: bookingId,
            callerUserId: '',
            callerRole: 'CUSTOMER',
            calleeUserId: '',
            status: CallStatus.failed,
            startedAt: DateTime.now(),
          );
      notifyListeners();
    }
  }

  Future<void> answer() async {
    final session = _currentSession;
    if (session == null) return;

    try {
      final updated = await repository.answerCall(bookingId, session.id);
      _currentSession = updated;
      _startDurationTicker();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to connect call.';
      notifyListeners();
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  Future<void> hangup() async {
    _stopDurationTicker();
    final session = _currentSession;
    if (session == null) return;

    _currentSession = session.copyWith(status: CallStatus.ended);
    notifyListeners();

    try {
      await repository.hangupCall(bookingId, session.id);
    } catch (_) {
      // Best-effort hangup
    }
  }

  void _startDurationTicker() {
    _ticker?.cancel();
    _elapsedSeconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _stopDurationTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopDurationTicker();
    _socketSub?.cancel();
    super.dispose();
  }
}
