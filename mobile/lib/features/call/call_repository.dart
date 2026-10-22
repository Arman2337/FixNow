import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

abstract class CallRepository {
  Future<CallSession> initiateCall(String bookingId);
  Future<CallSession?> getActiveCall(String bookingId);
  Future<CallSession> answerCall(String bookingId, String callId);
  Future<CallSession> rejectCall(String bookingId, String callId);
  Future<CallSession> hangupCall(String bookingId, String callId);
}

/// Server call signaling. A CONNECTED record does not establish audio media.
class HttpCallRepository implements CallRepository {
  HttpCallRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
  }) : _api = api,
       _accessToken = accessToken;
  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  Future<Object?> _request(ApiMethod method, String path) async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to manage calls.',
      );
    }
    final response = await _api.send(
      ApiRequest(method: method, path: path, bearerToken: token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        ApiFailureKind.server,
        'Could not update the call.',
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  CallSession _parse(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        raw['bookingId'] is! String ||
        raw['status'] is! String) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The call response was invalid.',
      );
    }
    return CallSession.fromJson(Map<String, Object?>.from(raw));
  }

  String _path(String bookingId) =>
      'bookings/${Uri.encodeComponent(bookingId.trim())}/calls';

  @override
  Future<CallSession> initiateCall(String bookingId) async {
    final raw = await _request(ApiMethod.post, '${_path(bookingId)}/initiate');
    return _parse(raw is Map ? raw['call'] : null);
  }

  @override
  Future<CallSession?> getActiveCall(String bookingId) async {
    final raw = await _request(ApiMethod.get, '${_path(bookingId)}/active');
    return raw == null ? null : _parse(raw);
  }

  Future<CallSession> _transition(
    String bookingId,
    String callId,
    String action,
  ) async => _parse(
    await _request(
      ApiMethod.post,
      '${_path(bookingId)}/${Uri.encodeComponent(callId)}/$action',
    ),
  );

  @override
  Future<CallSession> answerCall(String bookingId, String callId) =>
      _transition(bookingId, callId, 'answer');
  @override
  Future<CallSession> rejectCall(String bookingId, String callId) =>
      _transition(bookingId, callId, 'reject');
  @override
  Future<CallSession> hangupCall(String bookingId, String callId) =>
      _transition(bookingId, callId, 'hangup');
}
