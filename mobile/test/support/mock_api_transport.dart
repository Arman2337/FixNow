import 'package:fixnow_mobile/api/api_client.dart';

/// Test mock implementation of ApiTransport returning an empty 200 response by default.
class MockApiTransport implements ApiTransport {
  const MockApiTransport({this.onSend});

  final Future<ApiResponse> Function(ApiRequest request)? onSend;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (onSend != null) {
      return onSend!(request);
    }
    return const ApiResponse(statusCode: 200, body: []);
  }
}
