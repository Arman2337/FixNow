import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository, {RealtimeClient? realtime})
      : _realtime = realtime {
    _realtimeSubscription = _realtime?.notifications.listen(_onRealtimeNotification);
    load();
  }

  final NotificationRepository _repository;
  final RealtimeClient? _realtime;
  StreamSubscription<RealtimeProjection>? _realtimeSubscription;
  List<InAppNotification> _notifications = [];
  NotificationCategory _selectedCategory = NotificationCategory.all;
  bool _loading = false;
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
       _errorMessage = 'Notifications are unavailable. Check your connection and try again.';
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

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications = [
        ..._notifications.sublist(0, index),
        _notifications[index].copyWith(isRead: true),
        ..._notifications.sublist(index + 1),
      ];
      _repository.markAsRead(id);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (unreadCount == 0) return;
    _repository.markAllAsRead(
      _notifications.where((n) => !n.isRead).map((n) => n.id),
    );
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications = _notifications.where((n) => n.id != id).toList();
    _repository.deleteNotification(id);
    notifyListeners();
  }

  void clearAll() {
    _repository.clearAll(_notifications.map((n) => n.id));
    _notifications = [];
    notifyListeners();
  }

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
        InAppNotification.fromJson(
          Map<String, dynamic>.from(projection.data),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.cancel());
    super.dispose();
  }
}
