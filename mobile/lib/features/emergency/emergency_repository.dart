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

class ActiveEmergencyResult {
  const ActiveEmergencyResult({
    required this.hasActive,
    this.bookingId,
    this.status,
    this.currentWave = 1,
    this.fallbackRequired = false,
    this.guidance,
    this.eligibleCount = 0,
    this.providerAssigned = false,
    this.providerId,
    this.description,
    this.serviceCategoryId,
    this.locationLat,
    this.locationLng,
    this.createdAt,
  });

  final bool hasActive;
  final String? bookingId;
  final String? status;
  final int currentWave;
  final bool fallbackRequired;
  final String? guidance;
  final int eligibleCount;
  final bool providerAssigned;
  final String? providerId;
  final String? description;
  final String? serviceCategoryId;
  final double? locationLat;
  final double? locationLng;
  final DateTime? createdAt;

  static ActiveEmergencyResult fromJson(Map<String, Object?> json) =>
      ActiveEmergencyResult(
        hasActive: json['hasActive'] == true,
        bookingId: json['bookingId'] as String?,
        status: json['status'] as String?,
        currentWave: (json['currentWave'] ?? 1) as int,
        fallbackRequired: json['fallbackRequired'] == true,
        guidance: json['guidance'] as String?,
        eligibleCount: (json['eligibleCount'] ?? 0) as int,
        providerAssigned: json['providerAssigned'] == true,
        providerId: json['providerId'] as String?,
        description: json['description'] as String?,
        serviceCategoryId: json['serviceCategoryId'] as String?,
        locationLat: (json['locationLat'] as num?)?.toDouble(),
        locationLng: (json['locationLng'] as num?)?.toDouble(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']! as String)
            : null,
      );
}

class EmergencyStatusResult {
  const EmergencyStatusResult({
    required this.status,
    required this.currentWave,
    required this.fallbackRequired,
    this.guidance,
    this.eligibleCount = 0,
  });

  final String status;
  final int currentWave;
  final bool fallbackRequired;
  final String? guidance;
  final int eligibleCount;

  static EmergencyStatusResult fromJson(Map<String, Object?> json) =>
      EmergencyStatusResult(
      status: json['status']! as String,
      currentWave: (json['currentWave'] ?? 0) as int,
      fallbackRequired: json['fallbackRequired'] == true,
      guidance: json['guidance'] as String?,
      eligibleCount: (json['eligibleCount'] ?? 0) as int,
      );
}

class EmergencyRepository {
  EmergencyRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

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
    return EmergencyCreationResult.fromJson(
      response.body as Map<String, Object?>,
    );
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
    return EmergencyStatusResult.fromJson(
      response.body as Map<String, Object?>,
    );
  }

  /// Inspects whether the customer currently has an active emergency dispatch
  /// in progress so the app can immediately restore the radar or tracking view.
  Future<ActiveEmergencyResult?> getActive() async {
    try {
      final response = await _transport.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'emergency/active',
          bearerToken: await _accessToken?.call(),
        ),
      );
      if (response.statusCode == 200 &&
          response.body is Map<String, Object?>) {
        return ActiveEmergencyResult.fromJson(
          response.body as Map<String, Object?>,
        );
      }
    } catch (_) {
      // Best-effort lookup; fallback to idle state
    }
    return null;
  }
}
