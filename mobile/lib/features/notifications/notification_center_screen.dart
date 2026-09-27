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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notifications = controller.filteredNotifications;
        final unread = controller.unreadCount;

        return Scaffold(
           backgroundColor: AppColors.background,
          appBar: AppBar(
             backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 1,
           leading: IconButton(
             icon: const Icon(
               Icons.arrow_back_rounded,
               color: AppColors.textPrimary,
             ),
             onPressed: () => Navigator.of(context).maybePop(),
           ),
           title: Row(
             children: [
               const Expanded(
                 child: Text(
                   'Notifications & Activity',
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: TextStyle(
                     fontWeight: FontWeight.w800,
                     fontSize: 17,
                     letterSpacing: -0.3,
                     color: AppColors.textPrimary,
                   ),
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
                     color: AppColors.primarySoft,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     '$unread New',
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(
                       color: AppColors.primary,
                       fontSize: 11,
                       fontWeight: FontWeight.w800,
                     ),
                   ),
                 ),
               ],
             ],
           ),
           actions: [
             if (controller.notifications.isNotEmpty)
               IconButton(
                 tooltip: 'Clear all notifications',
                 icon: const Icon(
                   Icons.delete_sweep_outlined,
                   color: AppColors.textSecondary,
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
               _buildCategoryFilterStrip(context),
               if (unread > 0)
                 Padding(
                   padding: const EdgeInsets.only(
                     left: AppSpacing.pagePadding,
                     right: AppSpacing.pagePadding,
                     top: AppSpacing.xs,
                   ),
                   child: Align(
                     alignment: Alignment.centerRight,
                     child: TextButton.icon(
                       icon: const Icon(Icons.done_all_rounded, size: 18),
                       label: const Text('Mark read'),
                       onPressed: controller.markAllAsRead,
                     ),
                   ),
                 ),
               const SizedBox(height: AppSpacing.xs),

               Expanded(
                 child: notifications.isEmpty
                     ? controller.hasError
                         ? _buildErrorState(context)
                         : _buildEmptyState(context)
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
                             return _buildInboxFooter(context);
                           }
                           final item = notifications[index];
                           return _buildNotificationCard(context, item);
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
          final chipBg = isSelected
              ? AppColors.primary
              : AppColors.surfaceContainer;
          final chipFg = isSelected
              ? AppColors.onPrimary
              : AppColors.textSecondary;

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
                                ? AppColors.onPrimary.withValues(alpha: 0.18)
                                : AppColors.surfaceContainerLowest,
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
  ) {
    final isUnread = !item.isRead;
    final cardBgColor = isUnread
        ? AppColors.primarySoft
        : AppColors.surfaceContainerLowest;
    final cardBorderColor = isUnread
        ? AppColors.primary.withValues(alpha: 0.28)
        : AppColors.outline.withValues(alpha: 0.12);

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
          borderRadius: AppRadius.cardBorder,
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
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: cardBorderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.cardBorder,
              onTap: () {
                controller.markAsRead(item.id);
                if (item.category == NotificationCategory.payments ||
                    item.paymentId != null) {
                  if (onOpenInvoice != null) {
                    onOpenInvoice!(item);
                  } else {
                    _showInvoiceModal(context, item);
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
                         Row(
                           children: [
                             Expanded(
                               child: Row(
                                 children: [
                                   Flexible(
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 8,
                                         vertical: 3,
                                       ),
                                       decoration: BoxDecoration(
                                         color: isUnread
                                             ? AppColors.primarySoft
                                             : AppColors.surfaceContainer,
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
                                           Flexible(
                                             child: Text(
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
                                               maxLines: 1,
                                               overflow: TextOverflow.ellipsis,
                                               style: TextStyle(
                                                 fontSize: 10,
                                                 fontWeight: FontWeight.w800,
                                                 color: isUnread
                                                     ? AppColors.primary
                                                     : AppColors.textSecondary,
                                               ),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                   if (item.bookingId != null) ...[
                                     const SizedBox(width: 6),
                                     Flexible(
                                       child: Text(
                                         '#${item.bookingId!.length > 8 ? item.bookingId!.substring(0, 8).toUpperCase() : item.bookingId!.toUpperCase()}',
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: const TextStyle(
                                           fontSize: 11,
                                           fontWeight: FontWeight.w600,
                                           color: AppColors.textSecondary,
                                         ),
                                       ),
                                     ),
                                   ],
                                 ],
                               ),
                             ),
                             const SizedBox(width: AppSpacing.sm),
                             Flexible(
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Flexible(
                                     child: Text(
                                       item.timeAgo,
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                       style: const TextStyle(
                                         fontSize: 11,
                                         color: AppColors.textSecondary,
                                         fontWeight: FontWeight.w500,
                                       ),
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
                                  : AppColors.surfaceContainer,
                              child: Icon(
                                item.category.icon,
                                size: 18,
                                color: isUnread
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
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
                                      color: AppColors.textPrimary,
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
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
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
                               color: AppColors.surfaceContainerLow,
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: Row(
                               children: [
                                 Expanded(
                                   child: Row(
                                     children: [
                                       const Icon(
                                         Icons.receipt_long_rounded,
                                         size: 15,
                                         color: AppColors.primary,
                                       ),
                                       const SizedBox(width: 4),
                                       const Flexible(
                                         child: Text(
                                           'Payment update',
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                           style: TextStyle(
                                             fontSize: 11,
                                             fontWeight: FontWeight.w700,
                                             color: AppColors.primary,
                                           ),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(width: AppSpacing.sm),
                                 Flexible(
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       const Flexible(
                                         child: Text(
                                           'View Invoice',
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                           style: TextStyle(
                                             color: AppColors.primary,
                                             fontSize: 12,
                                             fontWeight: FontWeight.w700,
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 3),
                                       const Icon(
                                         Icons.arrow_forward_rounded,
                                         size: 13,
                                         color: AppColors.primary,
                                       ),
                                     ],
                                   ),
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
                               color: AppColors.surfaceContainerLow,
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: Row(
                               children: [
                                 const Expanded(
                                   child: Text(
                                     'Booking update',
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                     style: TextStyle(
                                       fontSize: 12,
                                       fontWeight: FontWeight.w700,
                                       color: AppColors.primary,
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: AppSpacing.sm),
                                 Flexible(
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       const Flexible(
                                         child: Text(
                                           'View Booking',
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                           style: TextStyle(
                                             color: AppColors.primary,
                                             fontSize: 12,
                                             fontWeight: FontWeight.w700,
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 3),
                                       const Icon(
                                         Icons.arrow_forward_rounded,
                                         size: 13,
                                         color: AppColors.primary,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
               color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Notifications unavailable',
              style: TextStyle(
                 color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.errorMessage ?? 'Try again in a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: controller.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                 color: AppColors.primarySoft,
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
                 color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No pending alerts or urgent updates right now. We\'ll buzz you when your next technician hits the road!',
              textAlign: TextAlign.center,
              style: TextStyle(
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

  Widget _buildInboxFooter(BuildContext context) {
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Clear all notifications?',
          style: TextStyle(
             color: AppColors.textPrimary,
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

  void _showInvoiceModal(BuildContext context, InAppNotification item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
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
                    'Invoice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Open the payment details to view the authoritative invoice, amount, and status.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
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
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
