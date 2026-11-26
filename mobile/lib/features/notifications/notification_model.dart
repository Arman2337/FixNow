import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';

enum NotificationCategory {
  all,
  bookings,
  payments,
  offers,
  system;

  String get label => switch (this) {
    NotificationCategory.all => 'All',
    NotificationCategory.bookings => 'Bookings',
    NotificationCategory.payments => 'Payments',
    NotificationCategory.offers => 'Offers',
    NotificationCategory.system => 'System',
  };

  IconData get icon => switch (this) {
    NotificationCategory.all => Icons.all_inbox_rounded,
    NotificationCategory.bookings => Icons.calendar_month_rounded,
    NotificationCategory.payments => Icons.receipt_long_rounded,
    NotificationCategory.offers => Icons.local_offer_rounded,
    NotificationCategory.system => Icons.shield_rounded,
  };

  Color get color => switch (this) {
    NotificationCategory.all => AppColors.primary,
    NotificationCategory.bookings => AppColors.primary,
    NotificationCategory.payments => AppColors.success,
    NotificationCategory.offers => AppColors.accentGold,
    NotificationCategory.system => AppColors.info,
  };
}

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.kind,
    this.bookingId,
    this.paymentId,
    this.actionUrl,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;

  /// The backend's routing key, e.g. `booking:provider:ASSIGNED` or
  /// `booking:customer:CANCELLED`. Null for kinds the server does not send.
  ///
  /// [category] is a coarse bucket derived from it and is not enough to tell
  /// a notification addressed to this role from one addressed to the other
  /// side of the same booking.
  final String? kind;
  final String? bookingId;
  final String? paymentId;
  final String? actionUrl;

  /// Whether this row was addressed to a provider rather than a customer.
  ///
  /// Unknown kinds default to `true` so a new server-side kind is still shown
  /// everywhere instead of silently disappearing from the provider workspace.
  bool get isProviderKind =>
      kind == null || kind!.startsWith('booking:provider:');

  /// A negative booking outcome (cancelled / expired).
  ///
  /// Used for tone only: a cancellation rendered in the same green as a
  /// successful booking reads as good news.
  bool get isCancellation =>
      (kind?.toUpperCase().contains('CANCELLED') ?? false) ||
      body.toLowerCase().contains('cancelled');

  InAppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    String? kind,
    String? bookingId,
    String? paymentId,
    String? actionUrl,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      kind: kind ?? this.kind,
      bookingId: bookingId ?? this.bookingId,
      paymentId: paymentId ?? this.paymentId,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    NotificationCategory parseCategory(String? cat) {
      if (cat == null) return NotificationCategory.system;
      final lower = cat.toLowerCase();
      if (lower.contains('book')) return NotificationCategory.bookings;
      if (lower.contains('pay') || lower.contains('invoice')) {
        return NotificationCategory.payments;
      }
      if (lower.contains('offer') ||
          lower.contains('promo') ||
          lower.contains('coupon')) {
        return NotificationCategory.offers;
      }
      return NotificationCategory.system;
    }

    return InAppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      category: parseCategory(
        json['category']?.toString() ?? json['kind']?.toString(),
      ),
      timestamp:
          DateTime.tryParse(
            json['timestamp']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      kind: json['kind']?.toString(),
      bookingId: json['bookingId']?.toString(),
      paymentId: json['paymentId']?.toString(),
      actionUrl: json['actionUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'kind': kind,
    'bookingId': bookingId,
    'paymentId': paymentId,
    'actionUrl': actionUrl,
  };
}
