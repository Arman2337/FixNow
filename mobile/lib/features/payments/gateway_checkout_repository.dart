import 'package:fixnow_mobile/api/api_client.dart';

class GatewayCheckoutRepository {
  GatewayCheckoutRepository(this._api, this._baseUri, this._accessToken);

  final ApiTransport _api;
  final Uri _baseUri;
  final Future<String?> Function() _accessToken;

  Future<bool> isAvailable() async =>
      (await _send(ApiMethod.get, 'payments/checkout/availability')
          as Map<String, Object?>)['available'] ==
      true;

  Future<String?> groupStatus(String groupId) async =>
      (await _send(ApiMethod.get, 'payments/orders/group-services/$groupId')
              as Map<String, Object?>?)?['status']
          as String?;

  Future<Uri> start(String id, {required bool group}) async {
    final subject = group ? 'group-services' : 'bookings';
    final data = await _send(
      ApiMethod.post,
      'payments/checkout/$subject/$id',
      body: group ? const {'serviceReceived': true} : null,
    );
    final token = data is Map<String, Object?> ? data['token'] : null;
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Checkout link unavailable.',
      );
    }
    return _baseUri.resolve('payments/checkout').replace(fragment: token);
  }

  Future<Object?> _send(
    ApiMethod method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to pay for this service.',
      );
    }
    return (await _api.send(
      ApiRequest(method: method, path: path, body: body, bearerToken: token),
    )).body;
  }
}
