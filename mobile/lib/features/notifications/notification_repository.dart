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

  void markAsRead(String id) {
    _readIds.add(id);
    if (api != null) {
      accessToken?.call().then((token) {
        api!.send(
          ApiRequest(
            method: ApiMethod.patch,
            path: 'users/me/notifications/$id/read',
            bearerToken: token,
          ),
        );
      }).catchError((_) {});
    }
  }

  void markAllAsRead(Iterable<String> ids) {
    for (final id in ids) {
      markAsRead(id);
    }
  }

  void deleteNotification(String id) {
    _deletedIds.add(id);
  }

  void clearAll(Iterable<String> ids) {
    _deletedIds.addAll(ids);
  }
}
