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
        if (response.statusCode == 200 && response.body is List) {
          final raw = response.body as List;
          remoteList = raw
              .whereType<Map>()
              .map(
                (m) => InAppNotification.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      } catch (_) {
        // No fallback, return what we have (empty or cached)
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

  void markAsRead(String id) {
    _readIds.add(id);
  }

  void markAllAsRead(Iterable<String> ids) {
    _readIds.addAll(ids);
  }

  void deleteNotification(String id) {
    _deletedIds.add(id);
  }

  void clearAll(Iterable<String> ids) {
    _deletedIds.addAll(ids);
  }
}
