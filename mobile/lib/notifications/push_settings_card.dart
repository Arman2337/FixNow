import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:flutter/material.dart';

/// Honest push-notification enrollment card. Every state reflects what the
/// current build and device can actually do; nothing pretends to work.
class PushSettingsCard extends StatefulWidget {
  const PushSettingsCard({required this.controller, super.key});

  final PushEnrollmentController controller;

  @override
  State<PushSettingsCard> createState() => _PushSettingsCardState();
}

class _PushSettingsCardState extends State<PushSettingsCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return FixCard(
        semanticLabel: 'Push notification settings',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_statusMessage(controller.status)),
            if (controller.status == PushEnrollmentStatus.ready &&
                controller.devices.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final device in controller.devices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        _platformIcon(device.platform),
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_platformLabel(device.platform))),
                      IconButton(
                        tooltip: 'Turn off notifications for this device',
                        onPressed: controller.busy
                            ? null
                            : () => controller.disable(device),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (controller.canEnable)
              FixButton(
                label: controller.devices.isEmpty
                    ? 'Enable notifications'
                    : 'Add this device',
                isLoading: controller.busy,
                variant: FixButtonVariant.secondary,
                onPressed: controller.enable,
              ),
            if (controller.status == PushEnrollmentStatus.error) ...[
              const SizedBox(height: AppSpacing.xs),
              FixButton(
                label: 'Try again',
                variant: FixButtonVariant.secondary,
                onPressed: controller.refresh,
              ),
            ],
          ],
        ),
      );
    },
  );

  String _statusMessage(PushEnrollmentStatus status) => switch (status) {
    PushEnrollmentStatus.disabled =>
      'Notifications are not included in this build.',
    PushEnrollmentStatus.unavailable =>
      'Push is unavailable on this device or configuration.',
    PushEnrollmentStatus.permissionDenied =>
      'Notification permission was declined. Allow notifications for FixNow in system settings, then try again.',
    PushEnrollmentStatus.error =>
      'We could not update your notification settings. Check your connection.',
    PushEnrollmentStatus.ready =>
      'Get booking updates even when the app is closed.',
  };

  IconData _platformIcon(String platform) => switch (platform) {
    'ANDROID' => Icons.android_rounded,
    'IOS' => Icons.phone_iphone_rounded,
    _ => Icons.web_rounded,
  };

  String _platformLabel(String platform) => switch (platform) {
    'ANDROID' => 'Android device',
    'IOS' => 'iPhone',
    _ => 'Web session',
  };
}
