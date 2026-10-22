import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository, {RealtimeClient? realtime})
    : _realtime = realtime {
    _realtimeSubscription = _realtime?.notifications.listen(
      _onRealtimeNotification,
    );
    load();
  }

  final NotificationRepository _repository;
  final RealtimeClient? _realtime;
  StreamSubscription<RealtimeProjection>? _realtimeSubscription;
  List<InAppNotification> _notifications = [];
  NotificationCategory _selectedCategory = NotificationCategory.all;
  bool _loading = false;
  bool _mutating = false;
  bool get isMutating => _mutating;
  String? _errorMessage;

  List<InAppNotification> get notifications =>
      List.unmodifiable(_notifications);
  NotificationCategory get selectedCategory => _selectedCategory;
  bool get isLoading => _loading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  int getCountForCategory(NotificationCategory category) {
    if (category == NotificationCategory.all) return _notifications.length;
    return _notifications.where((n) => n.category == category).length;
  }

  List<InAppNotification> get filteredNotifications {
    if (_selectedCategory == NotificationCategory.all) {
      return List.unmodifiable(_notifications);
    }
    return List.unmodifiable(
      _notifications.where((n) => n.category == _selectedCategory),
    );
  }

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _notifications = await _repository.fetchNotifications();
    } catch (_) {
      _errorMessage =
          'Notifications are unavailable. Check your connection and try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setFilter(NotificationCategory category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_mutating) return false;
    _mutating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (_) {
      _errorMessage =
          'Changes were not saved. Check your connection and try again.';
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(String id) => _mutate(() async {
    await _repository.markAsRead(id);
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  });

  Future<bool> markAllAsRead() => _mutate(() async {
    // Update individually so a partial failure still reflects confirmed writes.
    for (final id
        in _notifications.where((n) => !n.isRead).map((n) => n.id).toList()) {
      await _repository.markAsRead(id);
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
    }
  });

  Future<bool> deleteNotification(String id) => _mutate(() async {
    await _repository.deleteNotification(id);
    _notifications = _notifications.where((n) => n.id != id).toList();
  });

  Future<bool> clearAll() => _mutate(() async {
    final ids = _notifications.map((n) => n.id).toSet();
    await _repository.clearAll(ids);
    // Preserve notifications received while the request was in flight.
    _notifications = _notifications.where((n) => !ids.contains(n.id)).toList();
  });

  void addNotification(InAppNotification notification) {
    _errorMessage = null;
    _notifications = [
      notification,
      ..._notifications.where((n) => n.id != notification.id),
    ];
    notifyListeners();
  }

  void _onRealtimeNotification(RealtimeProjection projection) {
    try {
      addNotification(
        InAppNotification.fromJson(Map<String, dynamic>.from(projection.data)),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.cancel());
    super.dispose();
  }
}
