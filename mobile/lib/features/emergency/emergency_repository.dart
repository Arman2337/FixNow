import 'package:fixnow_mobile/api/api_client.dart';

/// FN-064: typed results mirroring the FN-063 backend emergency contracts.
class EmergencyCreationResult {
  const EmergencyCreationResult({
    required this.bookingId,
    required this.currentWave,
    required this.eligibleCount,
  });

  final String bookingId;
  final int currentWave;
  final int eligibleCount;

  static EmergencyCreationResult fromJson(Map<String, Object?> json) =>
      EmergencyCreationResult(
        bookingId: json['bookingId']! as String,
        currentWave: (json['currentWave'] ?? 0) as int,
        eligibleCount: (json['eligibleCount'] ?? 0) as int,
      );
}

class EmergencyStatusResult {
  const EmergencyStatusResult({
    required this.status,
    required this.currentWave,
    required this.fallbackRequired,
    required this.guidance,
  });

  final String status;
  final int currentWave;
  final bool fallbackRequired;
  final String? guidance;

  static EmergencyStatusResult fromJson(Map<String, Object?> json) =>
      EmergencyStatusResult(
        status: json['status']! as String,
        currentWave: (json['currentWave'] ?? 0) as int,
        fallbackRequired: json['fallbackRequired'] == true,
        guidance: json['guidance'] as String?,
      );
}

class EmergencyRepository {
  EmergencyRepository(this._transport, {Future<String?> Function()? accessToken})
    : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  /// Deliberate second step of the policy §3 journey. The idempotency key
  /// protects against double-taps under stress.
  Future<EmergencyCreationResult> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
  }) async {
    final key = 'emergency-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'emergency/requests',
        bearerToken: await _accessToken?.call(),
        headers: {'Idempotency-Key': key},
        body: {
          'serviceCategoryId': serviceCategoryId,
          'description': description.trim(),
          'locationLat': latitude,
          'locationLng': longitude,
        },
      ),
    );
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        response.body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.server,
        'The emergency alert could not be sent.',
      );
    }
    return EmergencyCreationResult.fromJson(response.body as Map<String, Object?>);
  }

  Future<EmergencyStatusResult> status(String bookingId) async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'emergency/requests/$bookingId',
        bearerToken: await _accessToken?.call(),
      ),
    );
    if (response.statusCode != 200 || response.body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected emergency status response.',
      );
    }
    return EmergencyStatusResult.fromJson(response.body as Map<String, Object?>);
  }
}
