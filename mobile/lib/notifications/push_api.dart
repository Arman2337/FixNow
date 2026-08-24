import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fixnow_mobile/api/api_client.dart';

class PushDeviceSummary {
  const PushDeviceSummary({
    required this.id,
    required this.platform,
    required this.createdAt,
  });

  factory PushDeviceSummary.fromJson(Map<String, Object?> json) =>
      PushDeviceSummary(
        id: json['id']! as String,
        platform: json['platform']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
      );

  final String id;
  final String platform;
  final DateTime createdAt;
}

/// Backend contract for push device registration. Tokens are write-only:
/// they are sent once and never returned by any endpoint.
class PushApi {
  PushApi(this._transport, {Future<String?> Function()? accessToken})
    : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  Future<String?> _token() async {
    final resolve = _accessToken;
    return resolve == null ? null : resolve();
  }

  Future<void> register({required String token, required String platform}) async {
    await _transport.send(
      ApiRequest(
        method: ApiMethod.put,
        path: 'notifications/push/devices',
        bearerToken: await _token(),
        body: {'token': token, 'platform': platform},
      ),
    );
  }

  Future<List<PushDeviceSummary>> list() async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'notifications/push/devices',
        bearerToken: await _token(),
      ),
    );
    if (response.statusCode != 200 || response.body is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected device list response.',
      );
    }
    return [
      for (final entry in response.body as List)
        PushDeviceSummary.fromJson(entry! as Map<String, Object?>),
    ];
  }

  Future<void> revoke(String deviceId) async {
    await _transport.send(
      ApiRequest(
        method: ApiMethod.delete,
        path: 'notifications/push/devices/$deviceId',
        bearerToken: await _token(),
      ),
    );
  }
}

String detectPushPlatform() {
  if (kIsWeb) return 'WEB';
  switch (Platform.operatingSystem) {
    case 'android':
      return 'ANDROID';
    case 'ios':
      return 'IOS';
    default:
      return 'WEB';
  }
}
