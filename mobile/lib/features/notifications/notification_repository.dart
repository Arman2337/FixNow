import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';

class NotificationRepository {
  NotificationRepository({
    this.api,
    this.accessToken,
  });

  final ApiTransport? api;
  final Future<String?> Function()? accessToken;

  final Set<String> _readIds = {};
  final Set<String> _deletedIds = {};

  static final List<InAppNotification> _defaultSeed = [
    InAppNotification(
      id: 'notif-seed-1',
      title: 'Booking Confirmed & Assigned',
      body: 'Verified expert Ramesh K. has accepted your electrical repair request.',
      category: NotificationCategory.bookings,
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      isRead: false,
      bookingId: 'booking-seed-1',
    ),
    InAppNotification(
      id: 'notif-seed-2',
      title: 'Welcome Offer: ₹100 Off',
      body: 'Use promo code WELCOME100 on your first booking checkout to get ₹100 instant discount.',
      category: NotificationCategory.offers,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    InAppNotification(
      id: 'notif-seed-3',
      title: 'Payment Invoice Ready',
      body: 'Invoice INV-2026-0824 for Plumbing Service has been generated and marked paid.',
      category: NotificationCategory.payments,
      timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      isRead: true,
      paymentId: 'pay-seed-1',
    ),
    InAppNotification(
      id: 'notif-seed-4',
      title: 'Trust & Safety Assurance',
      body: 'All FixNow professionals have verified background checks, identity proof, and skill tests.',
      category: NotificationCategory.system,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  Future<List<InAppNotification>> fetchNotifications() async {
    List<InAppNotification> remoteList = [];
    if (api != null) {
      try {
        final token = accessToken != null ? await accessToken!() : null;
        final response = await api!.send(
          ApiRequest(
            method: ApiMethod.get,
            path: 'notifications/inbox',
            bearerToken: token,
          ),
        );
        if (response.statusCode == 200 && response.body is Map) {
          final raw = (response.body as Map)['notifications'];
          if (raw is List) {
            remoteList = raw
                .whereType<Map>()
                .map((m) => InAppNotification.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        }
      } catch (_) {
        // Fallback to local items gracefully on offline or absent network
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
    for (final item in _defaultSeed) {
      if (!_deletedIds.contains(item.id) && !combined.containsKey(item.id)) {
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
