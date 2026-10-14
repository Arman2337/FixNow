import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class CallController extends ChangeNotifier {
  CallController({this.repository, this.realtimeClient}) {
    _subscribeRealtime();
  }

  final CallRepository? repository;
  final RealtimeClient? realtimeClient;

  CallSession? activeSession;
  bool isInitiating = false;
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

  Future<CallSession?> startCall(String bookingId, {String? fallbackPhoneNumber}) async {
    if (repository != null) {
      try {
        isInitiating = true;
        notifyListeners();
        final session = await repository!.initiateCall(bookingId);
        activeSession = session;
        isInitiating = false;
        notifyListeners();
        return session;
      } catch (e) {
        debugPrint('[CallController] Error initiating call via API: $e');
        isInitiating = false;
        notifyListeners();
      }
    }
    if (fallbackPhoneNumber != null && fallbackPhoneNumber.isNotEmpty) {
      await launchCall(fallbackPhoneNumber);
    }
    return null;
  }

  Future<void> launchCall(String phoneNumber) async {
    await launchPhoneCall(phoneNumber);
  }

  static Future<void> launchPhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('[CallController] Could not launch tel: URI for $phoneNumber');
      }
    } catch (e) {
      debugPrint('[CallController] Error launching call: $e');
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
