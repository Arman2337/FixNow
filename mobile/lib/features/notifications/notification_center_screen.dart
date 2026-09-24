import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
    required this.controller,
    this.onOpenBooking,
    this.onOpenInvoice,
  });

  final NotificationController controller;
  final void Function(String bookingId)? onOpenBooking;
  final void Function(InAppNotification notification)? onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notifications = controller.filteredNotifications;
        final unread = controller.unreadCount;

        return Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundSecondary
              : AppColors.surface,
          appBar: AppBar(
            backgroundColor: isDark
                ? AppColors.backgroundSecondary
                : AppColors.surface.withValues(alpha: 0.95),
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Row(
              children: [
                Text(
                  'Notifications & Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.cream : AppColors.textPrimary,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread New',
                      style: const TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (unread > 0)
                TextButton.icon(
                  icon: const Icon(
                    Icons.done_all_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Mark read',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: controller.markAllAsRead,
                ),
              if (controller.notifications.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all notifications',
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
                  ),
                  onPressed: () => _confirmClearAll(context),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                // Category Filter Strip
                _buildCategoryFilterStrip(context, isDark),
                const SizedBox(height: AppSpacing.xs),

                // Notification list or empty view
                Expanded(
                  child: notifications.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pagePadding,
                            vertical: AppSpacing.sm,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: notifications.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            if (index == notifications.length) {
                              return _buildInboxFooter(context, isDark);
                            }
                            final item = notifications[index];
                            return _buildNotificationCard(
                              context,
                              item,
                              isDark,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilterStrip(BuildContext context, bool isDark) {
    final categories = NotificationCategory.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: categories.map((cat) {
          final isSelected = controller.selectedCategory == cat;
          final count = controller.getCountForCategory(cat);

          final chipBg = isSelected
              ? (isDark ? Colors.white : AppColors.textPrimary)
              : (isDark
                    ? AppColors.surfaceElevated
                    : AppColors.surfaceContainer);
          final chipFg = isSelected
              ? (isDark ? AppColors.backgroundSecondary : AppColors.surface)
              : (isDark ? AppColors.textSecondary : AppColors.textSecondary);

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.setFilter(cat),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: chipFg,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? Colors.black.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.25))
                                : (isDark
                                      ? AppColors.backgroundSecondary
                                      : AppColors.surfaceContainerLowest),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: chipFg,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    InAppNotification item,
    bool isDark,
  ) {
    final isUnread = !item.isRead;
    final cardBgColor = isDark
        ? (isUnread ? AppColors.surfaceElevated : const Color(0xFF0D1728))
        : AppColors.surfaceContainerLowest;
    final cardBorderColor = isDark
        ? (isUnread
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.borderDefault.withValues(alpha: 0.12))
        : AppColors.outline.withValues(alpha: isUnread ? 0.18 : 0.08);

    Color stripeColor = AppColors.primary;
    if (item.category == NotificationCategory.system) {
      stripeColor = AppColors.secondary;
    } else if (item.category == NotificationCategory.offers) {
      stripeColor = AppColors.tertiary;
    } else if (item.category == NotificationCategory.payments) {
      stripeColor = AppColors.primary;
    }

    return Dismissible(
      key: Key('notif-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dismiss',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ],
        ),
      ),
      onDismissed: (_) => controller.deleteNotification(item.id),
      child: Semantics(
        label: '${item.title}. ${item.body}',
        button: true,
        child: Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                controller.markAsRead(item.id);
                if (item.category == NotificationCategory.payments ||
                    item.paymentId != null) {
                  if (onOpenInvoice != null) {
                    onOpenInvoice!(item);
                  } else {
                    _showInvoiceModal(context, item, isDark);
                  }
                } else if (item.bookingId != null && onOpenBooking != null) {
                  onOpenBooking!(item.bookingId!);
                }
              },
              child: Stack(
                children: [
                  // Left Accent Stripe
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: stripeColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Category Pill, ID, TimeAgo & Unread Dot
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUnread
                                        ? AppColors.primaryFixed
                                        : (isDark
                                              ? AppColors.surfaceElevated
                                              : AppColors.surfaceContainer),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isUnread) ...[
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        switch (item.category) {
                                          NotificationCategory.bookings =>
                                            'Active Booking',
                                          NotificationCategory.payments =>
                                            'Tax Invoice',
                                          NotificationCategory.offers =>
                                            'Rewards & Perk',
                                          NotificationCategory.system =>
                                            'Trust & Safety',
                                          _ => 'Notice',
                                        },
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isUnread
                                              ? AppColors.onPrimaryFixed
                                              : (isDark
                                                    ? AppColors.textSecondary
                                                    : AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.bookingId != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '#${item.bookingId!.length > 8 ? item.bookingId!.substring(0, 8).toUpperCase() : item.bookingId!.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  item.timeAgo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textMuted
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title & Body
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isUnread
                                  ? AppColors.primarySoft
                                  : (isDark
                                        ? AppColors.surfaceElevated
                                        : AppColors.surfaceContainer),
                              child: Icon(
                                item.category.icon,
                                size: 18,
                                color: isUnread
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.textSecondary
                                          : AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.cream
                                          : AppColors.textPrimary,
                                      fontWeight: isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.body,
                                    style: TextStyle(
                                      color: isDark
                                          ? (isUnread
                                                ? AppColors.textSecondary
                                                : AppColors.textMuted)
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Action Panel (PIN / View Details / View Invoice)
                        if (item.category == NotificationCategory.payments ||
                            item.paymentId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundSecondary
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '30-Day Coverage Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'View Invoice',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.primaryFixed
                                            : AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: isDark
                                          ? AppColors.primaryFixed
                                          : AppColors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else if (item.bookingId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundSecondary
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'START PIN',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '4821',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'View Booking',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.primaryFixed
                                            : AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: isDark
                                          ? AppColors.primaryFixed
                                          : AppColors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.surfaceElevated
                    : AppColors.primarySoft,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You are all caught up!',
              style: TextStyle(
                color: isDark ? AppColors.cream : AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No pending alerts or urgent updates right now. We\'ll buzz you when your next technician hits the road!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxFooter(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () => _confirmClearAll(context),
            icon: const Icon(
              Icons.delete_sweep_outlined,
              size: 18,
              color: AppColors.error,
            ),
            label: const Text(
              'Clear all notifications',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'High-priority safety & emergency alerts remain accessible in your Order History.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.surfaceElevated
            : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear all notifications?',
          style: TextStyle(
            color: isDark ? AppColors.cream : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'All activity alerts will be permanently cleared from your inbox.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              controller.clearAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceModal(BuildContext context, InAppNotification item, bool isDark) {
    final invoiceNumber = RegExp(r'INV-[0-9-]+').firstMatch(item.body)?.group(0) ?? 'INV-2026-0824';
    final serviceName = item.body.contains('Plumbing') ? 'Plumbing Service' : 'Home Service';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoice $invoiceNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.cream : AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.body,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundSecondary : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Service', style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          serviceName,
                          style: TextStyle(
                            color: isDark ? AppColors.cream : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.md),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: TextStyle(color: AppColors.textSecondary)),
                        Text('PAID', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Divider(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          '₹649',
                          style: TextStyle(
                            color: isDark ? AppColors.cream : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
