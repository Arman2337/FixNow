import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';

class FixNotificationBellIcon extends StatelessWidget {
  const FixNotificationBellIcon({
    super.key,
    required this.controller,
    this.onTap,
  });

  final NotificationController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final unread = controller.unreadCount;
        final hasUnread = unread > 0;

        return Semantics(
          button: true,
          label: hasUnread
              ? 'Activity and notifications, $unread unread alerts'
              : 'Activity and notifications',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceElevated,
                  border: Border.all(
                    color: hasUnread
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.borderDefault,
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      hasUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_outlined,
                      color: hasUnread ? Colors.white : AppColors.textSecondary,
                      size: 22,
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emergency,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.surfaceElevated,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emergency.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
