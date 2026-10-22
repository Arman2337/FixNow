import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class CallController extends ChangeNotifier {
  CallController({this.repository, this.realtimeClient, this.phoneLauncher}) {
    _subscribeRealtime();
  }

  final CallRepository? repository;
  final RealtimeClient? realtimeClient;
  final Future<bool> Function(Uri)? phoneLauncher;

  CallSession? activeSession;
  bool isInitiating = false;
  String? errorMessage;
  StreamSubscription<RealtimeProjection>? _realtimeSub;

  void _subscribeRealtime() {
    if (realtimeClient == null) return;
    _realtimeSub = realtimeClient!.projections.listen((projection) {
      final type = projection.data['type'] as String?;
      if (type != null && type.startsWith('call.')) {
        final data = projection.data['data'];
        if (data is Map) {
          activeSession = CallSession.fromJson(Map<String, Object?>.from(data));
          notifyListeners();
        }
      }
    });
  }

  /// Creates signaling state only; production phone actions use launchCall.
  Future<CallSession?> startCall(
    String bookingId, {
    String? fallbackPhoneNumber,
  }) async {
    if (repository != null) {
      try {
        errorMessage = null;
        isInitiating = true;
        notifyListeners();
        final session = await repository!.initiateCall(bookingId);
        activeSession = session;
        isInitiating = false;
        notifyListeners();
        return session;
      } catch (e) {
        errorMessage = 'Could not start the call. Please try again.';
        isInitiating = false;
        notifyListeners();
      }
    }
    return null;
  }

  /// Server signaling only. These methods do not provide a media connection.
  Future<CallSession> _updateSession(
    Future<CallSession> Function(CallRepository repository, CallSession session)
    action,
  ) async {
    final session = activeSession;
    final repo = repository;
    if (repo == null || session == null) throw StateError('No active call.');
    final updated = await action(repo, session);
    activeSession = updated;
    notifyListeners();
    return updated;
  }

  Future<CallSession> answerCall() =>
      _updateSession((repo, call) => repo.answerCall(call.bookingId, call.id));
  Future<CallSession> rejectCall() =>
      _updateSession((repo, call) => repo.rejectCall(call.bookingId, call.id));
  Future<CallSession> hangupCall() =>
      _updateSession((repo, call) => repo.hangupCall(call.bookingId, call.id));

  static Uri? phoneUri(String phoneNumber) {
    final input = phoneNumber.trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(input)) return null;
    final normalized = input.replaceAll(RegExp(r'[ ()-]'), '');
    final digits = normalized.replaceFirst('+', '');
    if (digits.length < 7 || digits.length > 15) return null;
    return Uri(scheme: 'tel', path: normalized);
  }

  Future<bool> launchCall(String phoneNumber) async {
    final uri = phoneUri(phoneNumber);
    if (uri == null) return false;
    try {
      return phoneLauncher != null
          ? await phoneLauncher!(uri)
          : await launchPhoneCall(phoneNumber);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchPhoneCall(String phoneNumber) async {
    final uri = phoneUri(phoneNumber);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
