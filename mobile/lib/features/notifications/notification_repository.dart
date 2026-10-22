import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';

class NotificationRepository {
  NotificationRepository({this.api, this.accessToken});

  final ApiTransport? api;
  final Future<String?> Function()? accessToken;

  final Set<String> _readIds = {};
  final Set<String> _deletedIds = {};

  Future<List<InAppNotification>> fetchNotifications() async {
    List<InAppNotification> remoteList = [];
    if (api != null) {
      try {
        final token = accessToken != null ? await accessToken!() : null;
        final response = await api!.send(
          ApiRequest(
            method: ApiMethod.get,
            path: 'users/me/notifications',
            bearerToken: token,
          ),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(
            ApiFailureKind.server,
            'Notifications are temporarily unavailable.',
            statusCode: response.statusCode,
          );
        }
        if (response.body is! List) {
          throw const ApiException(
            ApiFailureKind.invalidResponse,
            'Notifications returned an invalid response.',
          );
        }
        final raw = response.body as List;
        remoteList = raw
            .whereType<Map>()
            .map(
              (m) => InAppNotification.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
      } on ApiException {
        rethrow;
      } catch (_) {
        throw const ApiException(
          ApiFailureKind.server,
          'Notifications are temporarily unavailable.',
        );
      }
    }

    final combined = <String, InAppNotification>{};
    for (final item in remoteList) {
      if (!_deletedIds.contains(item.id)) {
        combined[item.id] = item.copyWith(
          isRead: item.isRead || _readIds.contains(item.id),
        );
      }
    }

    final list = combined.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Await the server before changing local visibility or read state.
  Future<void> _mutate(ApiMethod method, String path) async {
    if (api == null) return; // Explicit local-only repository used by tests.
    final token = await accessToken?.call();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to update notifications.',
      );
    }
    final response = await api!.send(
      ApiRequest(method: method, path: path, bearerToken: token),
    );
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.body is! Map ||
        (response.body as Map)['success'] != true) {
      throw ApiException(
        ApiFailureKind.server,
        'Could not update notifications.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> markAsRead(String id) async {
    await _mutate(
      ApiMethod.patch,
      'users/me/notifications/${Uri.encodeComponent(id)}/read',
    );
    _readIds.add(id);
  }

  Future<void> markAllAsRead(Iterable<String> ids) async {
    for (final id in ids.toList()) {
      await markAsRead(id);
    }
  }

  Future<void> deleteNotification(String id) async {
    await _mutate(
      ApiMethod.delete,
      'users/me/notifications/${Uri.encodeComponent(id)}',
    );
    _deletedIds.add(id);
  }

  Future<void> clearAll(Iterable<String> ids) async {
    final clearedIds = ids.toSet();
    await _mutate(ApiMethod.delete, 'users/me/notifications');
    _deletedIds.addAll(clearedIds);
  }
}
