import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

abstract class CallRepository {
  Future<CallSession> initiateCall(String bookingId);
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
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/calls/initiate',
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
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
  Future<CallSession> answerCall(String bookingId, String callId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/calls/$callId/answer',
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    if (body == null) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to answer call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(body));
  }

  @override
  Future<CallSession> rejectCall(String bookingId, String callId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/calls/$callId/reject',
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    if (body == null) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to reject call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(body));
  }

  @override
  Future<CallSession> hangupCall(String bookingId, String callId) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/calls/$callId/hangup',
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    if (body == null) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unable to end call.',
      );
    }

    return CallSession.fromJson(Map<String, Object?>.from(body));
  }
}
