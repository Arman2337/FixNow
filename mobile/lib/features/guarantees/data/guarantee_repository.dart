import 'package:fixnow_mobile/api/api_client.dart';
import '../models/guarantee_claim.dart';

class GuaranteeRepository {
  GuaranteeRepository(
    this._transport, {
    required Future<String?> Function() accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function() _accessToken;

  Future<String> _requireToken() async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(ApiFailureKind.unauthorized, 'Not logged in.');
    }
    return token;
  }

  Future<GuaranteeClaim> submitClaim({
    required String bookingId,
    required String description,
    List<String>? evidenceUrls,
  }) async {
    final token = await _requireToken();

    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'guarantees/claims',
        bearerToken: token,
        body: {
          'bookingId': bookingId,
          'description': description,
          if (evidenceUrls != null) 'evidenceUrls': evidenceUrls,
        },
      ),
    );

    return GuaranteeClaim.fromJson(response.body as Map<String, Object?>);
  }
}
