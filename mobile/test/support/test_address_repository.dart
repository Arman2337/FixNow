import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';

/// Explicit test fixture; no mock transport is imported by application sources.
SavedAddressRepository createTestAddressRepository() => SavedAddressRepository(
  api: const _AddressTestTransport(),
  accessToken: () async => '',
);

class _AddressTestTransport implements ApiTransport {
  const _AddressTestTransport();
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: []);
}
