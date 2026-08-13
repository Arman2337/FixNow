import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';

class ProviderRepository {
  ProviderRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
  }) : _api = api,
       _accessToken = accessToken;
  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  Future<String> _token() async =>
      (await _accessToken()) ??
      (throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in required.',
      ));
  Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value as Map);

  Future<ProviderApplication> application() async =>
      ProviderApplication.fromJson(
        _map(
          (await _api.send(
            ApiRequest(
              method: ApiMethod.get,
              path: 'provider-applications/me',
              bearerToken: await _token(),
            ),
          )).body,
        ),
      );

  Future<ProviderProfile?> profile() async {
    try {
      final response = await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'provider-profile/me',
          bearerToken: await _token(),
        ),
      );
      return ProviderProfile.fromJson(_map(response.body));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ProviderProfile> saveProfile(ProviderProfile profile) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.put,
        path: 'provider-profile/me',
        bearerToken: await _token(),
        body: {
          'displayName': profile.displayName,
          'bio': profile.bio,
          'serviceRadiusKm': profile.serviceRadiusKm,
          'baseLatitude': profile.baseLatitude,
          'baseLongitude': profile.baseLongitude,
        },
      ),
    );
    return ProviderProfile.fromJson(_map(response.body));
  }

  Future<ProviderAvailability> availability() async =>
      ProviderAvailability.fromJson(
        _map(
          (await _api.send(
            ApiRequest(
              method: ApiMethod.get,
              path: 'provider-availability/me',
              bearerToken: await _token(),
            ),
          )).body,
        ),
      );

  Future<ProviderAvailability> setStatus(
    ProviderAvailability current,
    String status,
  ) async => ProviderAvailability.fromJson(
    _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.put,
          path: 'provider-availability/me/status',
          bearerToken: await _token(),
          body: {'status': status, 'expectedVersion': current.version},
        ),
      )).body,
    ),
  );

  Future<List<CustomerBooking>> jobs() async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'bookings?limit=30',
          bearerToken: await _token(),
        ),
      )).body,
    );
    return (body['bookings'] as List)
        .map((row) => CustomerBooking.fromJson(_map(row)))
        .toList();
  }
}
