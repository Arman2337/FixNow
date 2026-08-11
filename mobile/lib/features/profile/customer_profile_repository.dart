import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/profile/customer_profile.dart';

abstract interface class CustomerProfileRepository {
  Future<CustomerProfile> read();
  Future<CustomerProfile> update(String displayName);
}

class ApiCustomerProfileRepository implements CustomerProfileRepository {
  const ApiCustomerProfileRepository({
    required ApiTransport api,
    required this.accessToken,
  }) : _api = api;
  final ApiTransport _api;
  final Future<String?> Function() accessToken;

  @override
  Future<CustomerProfile> read() async => CustomerProfile.fromJson(
    (await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'users/me/profile',
        bearerToken: await _requireToken(),
      ),
    )).body,
  );

  @override
  Future<CustomerProfile> update(String displayName) async =>
      CustomerProfile.fromJson(
        (await _api.send(
          ApiRequest(
            method: ApiMethod.patch,
            path: 'users/me/profile',
            bearerToken: await _requireToken(),
            body: {'displayName': displayName.trim()},
          ),
        )).body,
      );

  Future<String> _requireToken() async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to manage your profile.',
      );
    }
    return token;
  }
}
