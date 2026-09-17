import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/features/call/call_audio_service.dart';
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
    bool initialSpeakerOn = true,
  }) : _currentSession = initialSession,
       _isSpeakerOn = initialSpeakerOn {
    if (autoStart && _currentSession == null) {
      startCall();
    } else if (_currentSession != null &&
        _currentSession!.status == CallStatus.connected) {
      _startDurationTicker();
      _startVoiceAudio();
    } else if (_currentSession != null &&
        (_currentSession!.status == CallStatus.initiated ||
            _currentSession!.status == CallStatus.ringing)) {
      _startPollingReconciliation();
    }
    _listenToRealtime();
    realtimeClient?.subscribeBooking(bookingId);
    realtimeClient?.addListener(_onRealtimeChange);
  }

  final String bookingId;
  final CallRepository repository;
  final RealtimeClient? realtimeClient;
  final bool autoStart;

  CallSession? _currentSession;
  bool _isLoading = false;
  bool _isMuted = false;
  bool _isSpeakerOn;
  bool _isVoiceAudioActive = false;
  bool _isRemoteSpeaking = false;
  bool _isLocalSpeaking = false;
  bool _isReconnecting = false;
  int _elapsedSeconds = 0;
  String? _errorMessage;
  Timer? _ticker;
  Timer? _pollTimer;
  Timer? _remoteSpeakingTimer;
  Timer? _localSpeakingTimer;
  StreamSubscription<RealtimeProjection>? _socketSub;
  StreamSubscription? _voiceSub;

  CallSession? get currentSession => _currentSession;
  CallStatus get status => _currentSession?.status ?? CallStatus.initiated;
  bool get isLoading => _isLoading;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isRemoteSpeaking => _isRemoteSpeaking;
  bool get isLocalSpeaking => _isLocalSpeaking;
  bool get isReconnecting => _isReconnecting;
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

      final incomingBookingId =
          data['bookingId']?.toString() ??
          projection.data['resourceId']?.toString();
      if (incomingBookingId != null &&
          incomingBookingId.trim().toLowerCase() !=
              bookingId.trim().toLowerCase()) {
        return;
      }

      if (type == 'call.incoming.v1') {
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        notifyListeners();
      } else if (type == 'call.answered.v1') {
        _stopPollingReconciliation();
        CallAudioService.stop();
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _startDurationTicker();
        _startVoiceAudio();
        notifyListeners();
      } else if (type == 'call.rejected.v1') {
        _stopPollingReconciliation();
        CallAudioService.stop();
        _stopVoiceAudio();
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _stopDurationTicker();
        notifyListeners();
      } else if (type == 'call.ended.v1') {
        _stopPollingReconciliation();
        CallAudioService.stop();
        _stopVoiceAudio();
        _currentSession = CallSession.fromJson(Map<String, Object?>.from(data));
        _stopDurationTicker();
        notifyListeners();
      }
    });
  }

  void _startPollingReconciliation() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      await _pollActiveStatus();
    });
  }

  void _stopPollingReconciliation() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollActiveStatus() async {
    try {
      final active = await repository.getActiveCall(bookingId);
      if (active != null) {
        if (active.status == CallStatus.connected &&
            _currentSession?.status != CallStatus.connected) {
          _stopPollingReconciliation();
          CallAudioService.stop();
          _currentSession = active;
          _startDurationTicker();
          _startVoiceAudio();
          notifyListeners();
        } else if (active.status == CallStatus.ended ||
            active.status == CallStatus.rejected) {
          _stopPollingReconciliation();
          CallAudioService.stop();
          _stopVoiceAudio();
          _currentSession = active;
          _stopDurationTicker();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void _startVoiceAudio() {
    if (_isVoiceAudioActive) return;
    _isVoiceAudioActive = true;
    _voiceSub?.cancel();
    final callId = _currentSession?.id ?? '';
    debugPrint(
      '[CallController] Starting voice audio for booking=$bookingId, callId=$callId',
    );

    // Ensure booking channel is subscribed so we receive remote voice frames
    realtimeClient?.subscribeBooking(bookingId);

    // Listen to incoming remote voice frames from WebSocket
    if (realtimeClient != null) {
      _voiceSub = realtimeClient!.voiceFrames.listen((frame) {
        final frameBookingId = frame['bookingId']?.toString();
        if (frameBookingId != null &&
            frameBookingId.trim().toLowerCase() !=
                bookingId.trim().toLowerCase()) {
          return;
        }
        final base64Chunk = frame['data']?.toString();
        if (base64Chunk != null && base64Chunk.isNotEmpty) {
          try {
            final bytes = base64Decode(base64Chunk);
            if (bytes.isNotEmpty) {
              _remoteSpeakingTimer?.cancel();
              if (!_isRemoteSpeaking) {
                _isRemoteSpeaking = true;
                notifyListeners();
              }
              _remoteSpeakingTimer = Timer(
                const Duration(milliseconds: 400),
                () {
                  _isRemoteSpeaking = false;
                  notifyListeners();
                },
              );
            }
            CallAudioService.playVoiceChunk(bytes);
          } catch (e) {
            debugPrint('[CallController] Error playing chunk: $e');
          }
        }
      });
    }

    // Start native AudioRecord and AudioTrack
    CallAudioService.startVoiceStream(
      isSpeaker: _isSpeakerOn,
      onVoiceChunk: (chunk) {
        if (_isMuted || realtimeClient == null) return;

        // Calculate max amplitude for speech detection & silence gating
        int maxAmp = 0;
        for (int i = 0; i < chunk.length - 1; i += 2) {
          int sample = (chunk[i + 1] << 8) | chunk[i];
          if (sample > 32767) sample -= 65536;
          final abs = sample.abs();
          if (abs > maxAmp) maxAmp = abs;
        }

        if (maxAmp > 500) {
          _localSpeakingTimer?.cancel();
          if (!_isLocalSpeaking) {
            _isLocalSpeaking = true;
            notifyListeners();
          }
          _localSpeakingTimer = Timer(const Duration(milliseconds: 400), () {
            _isLocalSpeaking = false;
            notifyListeners();
          });
        }

        // Silence gating: skip purely silent frames (< 200 amplitude) to save ~60% cellular bandwidth
        if (maxAmp < 200) return;

        final base64Data = base64Encode(chunk);
        realtimeClient!.sendVoiceFrame(
          bookingId: bookingId,
          callId: callId,
          base64Data: base64Data,
        );
      },
    );
    CallAudioService.setSpeaker(_isSpeakerOn);
  }

  void _stopVoiceAudio() {
    _isVoiceAudioActive = false;
    _remoteSpeakingTimer?.cancel();
    _localSpeakingTimer?.cancel();
    _isRemoteSpeaking = false;
    _isLocalSpeaking = false;
    _voiceSub?.cancel();
    _voiceSub = null;
    CallAudioService.stopVoiceStream();
  }

  Future<void> startCall() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await repository.initiateCall(bookingId);
      _currentSession = session;
      _isLoading = false;
      // Start telecom ringback tone for caller
      CallAudioService.playRingback();
      _startPollingReconciliation();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not place audio call. Please check connection.';
      CallAudioService.stop();
      _stopPollingReconciliation();
      _currentSession =
          _currentSession?.copyWith(status: CallStatus.failed) ??
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

    _stopPollingReconciliation();
    CallAudioService.stop();

    try {
      final updated = await repository.answerCall(bookingId, session.id);
      _currentSession = updated;
      _startDurationTicker();
      _startVoiceAudio();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to connect call.';
      notifyListeners();
    }
  }

  Future<void> decline() async {
    _stopPollingReconciliation();
    CallAudioService.stop();
    _stopVoiceAudio();
    _stopDurationTicker();
    final session = _currentSession;
    if (session == null) return;

    _currentSession = session.copyWith(status: CallStatus.rejected);
    notifyListeners();

    try {
      await repository.rejectCall(bookingId, session.id);
    } catch (_) {
      // Best-effort reject
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    CallAudioService.setMute(_isMuted);
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    CallAudioService.setSpeaker(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> hangup() async {
    _stopPollingReconciliation();
    CallAudioService.stop();
    _stopVoiceAudio();
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

  void _onRealtimeChange() {
    if (status == CallStatus.connected && realtimeClient != null) {
      final reconnecting = !realtimeClient!.isConnected;
      if (_isReconnecting != reconnecting) {
        _isReconnecting = reconnecting;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    realtimeClient?.removeListener(_onRealtimeChange);
    _stopPollingReconciliation();
    CallAudioService.stop();
    _stopVoiceAudio();
    _stopDurationTicker();
    _socketSub?.cancel();
    super.dispose();
  }
}
