import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notifications = controller.filteredNotifications;
        final unread = controller.unreadCount;

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            title: const Text(
              'Notifications & Activity',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.cream,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppColors.borderDefault.withValues(alpha: 0.12),
              ),
            ),
            actions: [
              if (unread > 0)
                TextButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.primary),
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
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          side: BorderSide(
                            color: AppColors.borderDefault.withValues(alpha: 0.25),
                          ),
                        ),
                        title: const Text(
                          'Clear all notifications?',
                          style: TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        content: const Text(
                          'All activity alerts will be permanently cleared from your inbox.',
                          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
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
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: FixPageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  // Category Filter Chips Strip
                  _buildCategoryFilterStrip(context),
                  const SizedBox(height: AppSpacing.xs),

                  // Notifications list or empty view
                  Expanded(
                    child: notifications.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pagePadding,
                              vertical: AppSpacing.md,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: notifications.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              return _buildNotificationCard(context, item);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilterStrip(BuildContext context) {
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
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.setFilter(cat),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderDefault.withValues(alpha: 0.22),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 15,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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

  Widget _buildNotificationCard(BuildContext context, InAppNotification item) {
    final isUnread = !item.isRead;
    // Unread cards use vibrant elevated navy; read cards use a subtle deep midnight navy
    final cardBgColor = isUnread
        ? AppColors.surfaceElevated
        : const Color(0xFF0D1728);
    final cardBorderColor = isUnread
        ? AppColors.primary.withValues(alpha: 0.45)
        : AppColors.borderDefault.withValues(alpha: 0.12);

    return Dismissible(
      key: Key('notif-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dismiss',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
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
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: cardBorderColor, width: 1.2),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () {
                controller.markAsRead(item.id);
                if (item.category == NotificationCategory.payments || item.paymentId != null) {
                  if (onOpenInvoice != null) {
                    onOpenInvoice!(item);
                  } else {
                    _showInvoiceModal(context, item);
                  }
                } else if (item.bookingId != null && onOpenBooking != null) {
                  onOpenBooking!(item.bookingId!);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Icon Badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isUnread
                            ? item.category.color.withValues(alpha: 0.18)
                            : item.category.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: isUnread
                              ? item.category.color.withValues(alpha: 0.35)
                              : item.category.color.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        item.category.icon,
                        color: isUnread
                            ? item.category.color
                            : item.category.color.withValues(alpha: 0.75),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: isUnread
                                        ? AppColors.cream
                                        : AppColors.cream.withValues(alpha: 0.78),
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.body,
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.timeAgo,
                                style: TextStyle(
                                  color: isUnread
                                      ? AppColors.textMuted
                                      : AppColors.textDisabled,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.category == NotificationCategory.payments || item.paymentId != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Invoice',
                                      style: TextStyle(
                                        color: isUnread
                                            ? item.category.color
                                            : item.category.color.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: isUnread
                                          ? item.category.color
                                          : item.category.color.withValues(alpha: 0.8),
                                    ),
                                  ],
                                )
                              else if (item.bookingId != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Booking',
                                      style: TextStyle(
                                        color: isUnread
                                            ? item.category.color
                                            : item.category.color.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: isUnread
                                          ? item.category.color
                                          : item.category.color.withValues(alpha: 0.8),
                                    ),
                                  ],
                                ),
                            ],
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cat = controller.selectedCategory;
    final title = cat == NotificationCategory.all
        ? 'You are all caught up!'
        : 'No ${cat.label.toLowerCase()} notifications';
    final desc = cat == NotificationCategory.all
        ? 'When bookings, service progress, payments, or offers arrive, you will see them here.'
        : 'Any updates regarding ${cat.label.toLowerCase()} will be shown here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
                border: Border.all(
                  color: AppColors.borderDefault.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(cat.icon, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceModal(BuildContext context, InAppNotification item) {
    final invoiceNumber = RegExp(r'INV-[0-9-]+').firstMatch(item.body)?.group(0) ?? 'INV-2026-0824';
    final serviceName = item.body.contains('Plumbing') ? 'Plumbing Service' : 'Home Service';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.body,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Service', style: TextStyle(color: AppColors.textMuted)),
                        Text(serviceName, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: AppSpacing.md),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: TextStyle(color: AppColors.textMuted)),
                        Text('PAID', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: AppSpacing.md),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: TextStyle(color: AppColors.textMuted)),
                        Text('₹649', style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, fontSize: 16)),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
