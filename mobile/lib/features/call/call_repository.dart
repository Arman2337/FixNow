import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

abstract class CallRepository {
  Future<CallSession> initiateCall(String bookingId);
  Future<CallSession?> getActiveCall(String bookingId);
  Future<CallSession> answerCall(String bookingId, String callId);
  Future<CallSession> rejectCall(String bookingId, String callId);
  Future<CallSession> hangupCall(String bookingId, String callId);
}

class HttpCallRepository implements CallRepository {
  HttpCallRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
  }) : _api = api,
       _accessToken = accessToken;

  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  Future<String> _token() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to place in-app audio calls.',
      );
    }
    return token;
  }

  @override
  Future<CallSession> initiateCall(String bookingId) async {
    final cleanBookingId = bookingId.trim().toLowerCase();
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$cleanBookingId/calls/initiate',
        bearerToken: await _token(),
      ),
    );

    final raw = response.body;
    final Map<String, Object?>? body = raw is Map
        ? Map<String, Object?>.from(raw)
        : null;
    final callData = body?['call'];
    if (callData is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to initiate audio call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(callData));
  }

  @override
  Future<CallSession?> getActiveCall(String bookingId) async {
    try {
      final cleanBookingId = bookingId.trim().toLowerCase();
      final response = await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'bookings/$cleanBookingId/calls/active',
          bearerToken: await _token(),
        ),
      );

      final raw = response.body;
      if (raw is! Map) return null;
      return CallSession.fromJson(Map<String, Object?>.from(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CallSession> answerCall(String bookingId, String callId) async {
    final cleanBookingId = bookingId.trim().toLowerCase();
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$cleanBookingId/calls/$callId/answer',
        bearerToken: await _token(),
      ),
    );

    final raw = response.body;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to answer call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  Future<CallSession> rejectCall(String bookingId, String callId) async {
    final cleanBookingId = bookingId.trim().toLowerCase();
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$cleanBookingId/calls/$callId/reject',
        bearerToken: await _token(),
      ),
    );

    final raw = response.body;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to reject call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  Future<CallSession> hangupCall(String bookingId, String callId) async {
    final cleanBookingId = bookingId.trim().toLowerCase();
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$cleanBookingId/calls/$callId/hangup',
        bearerToken: await _token(),
      ),
    );

    final raw = response.body;
    if (raw is! Map) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to end call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(raw));
  }
}
