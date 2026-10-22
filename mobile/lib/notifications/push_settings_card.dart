import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Notification settings card for customer and provider profiles.
///
/// Provides a clear, accessible permission control:
/// - Checks real OS notification permission status.
/// - Allows granting notification permission with one tap.
/// - Directs to system settings if permanently denied.
/// - Explains that per-category controls are unavailable; device settings remain authoritative.
/// - Seamlessly integrates with [PushEnrollmentController] when push is configured.
class PushSettingsCard extends StatefulWidget {
  const PushSettingsCard({
    this.controller,
    this.initialPermissionStatus,
    this.onRequestPermission,
    super.key,
  });

  final PushEnrollmentController? controller;
  final PermissionStatus? initialPermissionStatus;
  final Future<PermissionStatus> Function()? onRequestPermission;

  @override
  State<PushSettingsCard> createState() => _PushSettingsCardState();
}

class _PushSettingsCardState extends State<PushSettingsCard>
    with WidgetsBindingObserver {
  PermissionStatus? _permissionStatus;
  bool _requesting = false;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionStatus = widget.initialPermissionStatus;
    if (_permissionStatus == null) {
      _checkPermission();
    }
    if (widget.controller?.devices.isEmpty ?? true) {
      widget.controller?.refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      widget.controller?.refresh();
    }
  }

  @override
  void didUpdateWidget(PushSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPermissionStatus != null &&
        widget.initialPermissionStatus != _permissionStatus) {
      _permissionStatus = widget.initialPermissionStatus;
    }
    if (oldWidget.controller != widget.controller) {
      widget.controller?.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPermission() async {
    if (widget.initialPermissionStatus != null) return;
    try {
      final status = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _permissionStatus = status;
        });
      }
    } catch (_) {
      if (mounted && _permissionStatus == null) {
        setState(() {
          _permissionStatus = PermissionStatus.denied;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting || (widget.controller?.busy ?? false)) return;
    setState(() {
      _requesting = true;
      _requestError = null;
    });
    try {
      final status = _permissionStatus?.isGranted == true
          ? _permissionStatus!
          : await (widget.onRequestPermission?.call() ??
                Permission.notification.request());
      if (!mounted) return;
      setState(() => _permissionStatus = status);
      if (!status.isGranted) {
        setState(
          () => _requestError = status.isPermanentlyDenied
              ? 'Notification permission is blocked. Allow it in device settings.'
              : 'Notification permission was not granted. You can try again.',
        );
        return;
      }
      final ctrl = widget.controller;
      if (ctrl == null) {
        setState(
          () => _requestError =
              'Device permission is allowed, but push registration is unavailable in this build.',
        );
        return;
      }
      await ctrl.enable();
      if (!mounted) return;
      if (ctrl.status != PushEnrollmentStatus.ready || ctrl.devices.isEmpty) {
        setState(
          () => _requestError =
              'Device permission is allowed, but push registration could not be completed. Try again.',
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission is allowed and push registration completed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _requestError =
              'Could not enable notifications. Check device settings and your connection, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _buildCardContent(context, controller),
      );
    }
    return _buildCardContent(context, null);
  }

  Widget _buildCardContent(
    BuildContext context,
    PushEnrollmentController? controller,
  ) {
    final isGranted = _permissionStatus?.isGranted == true;
    final isPermanentlyDenied = _permissionStatus?.isPermanentlyDenied == true;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppColors.primarySoft
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGranted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: isGranted
                      ? AppColors.primaryEmerald
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Arrival alerts, booking status & messages',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildStatusBadge(isGranted, isPermanentlyDenied),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_requestError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _requestError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // Body Content based on permission state
          if (isGranted) ...[
            const Text(
              'Device notification permission is allowed. Push delivery also requires registration with FixNow.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Per-category notification preferences are not available yet. Manage notification permission in your device settings.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (controller != null &&
                controller.status == PushEnrollmentStatus.ready &&
                controller.devices.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'REGISTERED DEVICES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final device in controller.devices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        _platformIcon(device.platform),
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _platformLabel(device.platform),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Turn off notifications for this device',
                        onPressed: controller.busy
                            ? null
                            : () => controller.disable(device),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
            ],
            if (controller != null &&
                (controller.devices.isEmpty || _requestError != null)) ...[
              const SizedBox(height: AppSpacing.sm),
              FixButton(
                label: 'Retry push registration',
                icon: Icons.refresh_rounded,
                variant: FixButtonVariant.secondary,
                isLoading: _requesting || controller.busy,
                onPressed: _requestPermission,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: openAppSettings,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Manage in device settings',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (isPermanentlyDenied) ...[
            const Text(
              'Notification permission is blocked in your device settings. Allow notifications for FixNow to receive live provider arrival and booking alerts.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FixButton(
              label: 'Open System Settings',
              icon: Icons.settings_rounded,
              variant: FixButtonVariant.secondary,
              onPressed: openAppSettings,
            ),
          ] else ...[
            const Text(
              'Allow FixNow to send you instant updates when a technician accepts your booking, is en route, or arrives at your address.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FixButton(
              label: 'Allow Notifications',
              icon: Icons.notifications_active_rounded,
              variant: FixButtonVariant.primary,
              isLoading: _requesting,
              onPressed: _requestPermission,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isGranted, bool isPermanentlyDenied) {
    if (isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: AppColors.success,
            ),
            SizedBox(width: 4),
            Text(
              'Permission allowed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }
    if (isPermanentlyDenied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 12,
              color: AppColors.warning,
            ),
            SizedBox(width: 4),
            Text(
              'Blocked',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Disabled',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

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
