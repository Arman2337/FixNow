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
          body: {
            'status': status, 
            'expectedVersion': current.version,
            if (status != 'offline') 
              'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 8)).toIso8601String(),
          },
        ),
      )).body,
    ),
  );

  Future<ProviderAvailability> setWeekdaySchedule(
    ProviderAvailability current,
    bool enabled,
  ) async => ProviderAvailability.fromJson(
    _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.put,
          path: 'provider-availability/me/schedule',
          bearerToken: await _token(),
          body: {
            'timeZone': current.timeZone,
            'weeklyRules': enabled
                ? [
                    for (var day = 1; day <= 5; day += 1)
                      {
                        'dayOfWeek': day,
                        'intervals': [
                          {'startMinute': 540, 'endMinute': 1020},
                        ],
                      },
                  ]
                : const [],
            'exceptions': const [],
            'expectedVersion': current.version,
          },
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

  Future<List<ProviderRequest>> availableRequests() async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'bookings/available?limit=30',
          bearerToken: await _token(),
        ),
      )).body,
    );
    final rows = body['bookings'];
    if (rows is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Available requests were invalid.',
      );
    }
    return rows
        .map((row) => ProviderRequest.fromJson(_map(row)))
        .toList(growable: false);
  }

  Future<CustomerBooking> acceptRequest(ProviderRequest request) async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'bookings/${request.id}/accept',
          bearerToken: await _token(),
          body: {'expectedVersion': request.version},
        ),
      )).body,
    );
    return CustomerBooking.fromJson(_map(body['booking']));
  }

  Future<List<ProviderSkill>> skills() async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'provider-skills/me',
        bearerToken: await _token(),
      ),
    );
    return (response.body as List)
        .map((row) => ProviderSkill.fromJson(_map(row)))
        .toList();
  }

  Future<List<Map<String, Object?>>> categories() async {
    final response = await _api.send(
      const ApiRequest(method: ApiMethod.get, path: 'service-categories'),
    );
    final body = response.body is Map ? _map(response.body) : null;
    final rows = body?['categories'] ?? response.body;
    return (rows as List).map(_map).toList();
  }

  Future<void> addSkill(String serviceCategoryId) async {
    await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'provider-skills',
        bearerToken: await _token(),
        body: {'serviceCategoryId': serviceCategoryId},
      ),
    );
  }

  Future<List<ProviderDocument>> documents() async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'provider-documents',
          bearerToken: await _token(),
        ),
      )).body,
    );
    return (body['documents'] as List)
        .map((row) => ProviderDocument.fromJson(_map(row)))
        .toList();
  }

  Future<void> uploadDocument({
    required String type,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) async {
    final api = _api;
    if (api is! ApiClient) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Document upload is unavailable.',
      );
    }
    await api.uploadFile(
      path: 'provider-documents/$type',
      bearerToken: await _token(),
      fieldName: 'document',
      fileName: name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<CustomerBooking> updateJobStatus(
    CustomerBooking job,
    String status,
  ) async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.patch,
          path: 'bookings/${job.id}/status',
          bearerToken: await _token(),
          body: {'status': status, 'expectedVersion': job.version},
        ),
      )).body,
    );
    return CustomerBooking.fromJson(_map(body['booking']));
  }

  Future<CustomerBooking> verifyOtpAndStartJob(
    CustomerBooking job,
    String otp,
  ) async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'bookings/${job.id}/start-service',
          bearerToken: await _token(),
          body: {'otp': otp, 'expectedVersion': job.version},
        ),
      )).body,
    );
    return CustomerBooking.fromJson(_map(body['booking']));
  }

  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    final body = _map(
      (await _api.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'bookings/${job.id}/cancel',
          bearerToken: await _token(),
          body: {'reason': reason.trim(), 'expectedVersion': job.version},
        ),
      )).body,
    );
    return CustomerBooking.fromJson(_map(body['booking']));
  }
}
