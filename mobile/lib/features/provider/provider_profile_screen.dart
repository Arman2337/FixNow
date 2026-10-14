import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_image.dart';
import 'package:fixnow_mobile/design_system/fix_schedule_hours_sheet.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:fixnow_mobile/notifications/push_settings_card.dart';

/// Dedicated Profile, Settings & Operations Hub for Verified Providers (Tab 3).
///
/// Keeps verified providers strictly separated from the 4-step applicant KYC onboarding wizard,
/// while providing full access to working hours, service radius, verified skills,
/// earnings shortcuts, notification preferences, and document management.
class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({
    required this.controller,
    required this.onSignOut,
    this.pushController,
    this.notificationController,
    this.onViewEarnings,
    this.onSupportCases,
    super.key,
  });

  final ProviderController controller;
  final VoidCallback onSignOut;
  final PushEnrollmentController? pushController;
  final NotificationController? notificationController;
  final VoidCallback? onViewEarnings;
  final VoidCallback? onSupportCases;

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  double? _serviceRadius;

  @override
  void initState() {
    super.initState();
    _serviceRadius = widget.controller.profile?.serviceRadiusKm;
  }

  Future<void> _saveRadius(double newRadius) async {
    final current = widget.controller.profile;
    if (current == null) return;

    final updated = ProviderProfile(
      displayName: current.displayName,
      bio: current.bio,
      serviceRadiusKm: newRadius,
      baseLatitude: current.baseLatitude,
      baseLongitude: current.baseLongitude,
      stats: current.stats,
    );

    try {
      await widget.controller.saveProfile(updated);
      if (mounted) {
        setState(() {
          _serviceRadius = newRadius;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Service radius updated to ${newRadius.toStringAsFixed(1)} km.',
            ),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update radius: ${widget.controller.actionError ?? e.toString()}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from your FixNow Provider account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onSignOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;
        final displayName = profile?.displayName ?? 'Verified Partner';
        final bio = profile?.bio ?? 'FixNow Certified Service Professional';
        final radius = _serviceRadius ?? profile?.serviceRadiusKm ?? 10.0;
        final stats = profile?.stats;
        final availability = widget.controller.availability;
        final skills = widget.controller.skills;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.95),
            elevation: 0,
            scrolledUnderElevation: 1,
            title: const Text(
              'Provider Profile & Hub',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Sign Out',
                icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                onPressed: _confirmSignOut,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity Card with Monogram Avatar & Verified Badge
                FixCard(
                  tone: FixCardTone.elevated,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FixAvatar(
                            name: displayName,
                            radius: 32,
                            verified: true,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: FixNowTypography.heading3.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'VERIFIED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: AppColors.primaryEmerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bio,
                                  style: FixNowTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1, color: AppColors.outlineVariant),
                      const SizedBox(height: AppSpacing.md),

                      // Metrics Strip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricColumn(
                            label: 'Rating',
                            value: stats != null && stats.hasRating
                                ? '⭐ ${stats.rating.toStringAsFixed(1)}'
                                : '⭐ New',
                            caption: stats != null && stats.hasRating
                                ? '(${stats.reviewCount})'
                                : 'No reviews',
                          ),
                          _MetricColumn(
                            label: 'Completed',
                            value: '${stats?.completedJobs ?? 0}',
                            caption: 'Jobs done',
                          ),
                          _MetricColumn(
                            label: 'Acceptance',
                            value: '${stats?.acceptanceRate ?? 100}%',
                            caption: 'Response rate',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Working Hours & Schedule Section
                FixCard(
                  tone: FixCardTone.standard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Working Hours & Shifts',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => FixProviderWorkingHoursSheet.show(
                              context,
                              controller: widget.controller,
                            ),
                            child: const Text('Edit Hours'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        availability?.scheduleSummary ?? 'Mon–Sat · 09:00–17:00 (Default)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dispatch algorithms assign instant repair leads only during your active shifts.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Service Radius Card
                FixCard(
                  tone: FixCardTone.standard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.radar_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Service Dispatch Radius',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${radius.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: radius.clamp(1.0, 50.0),
                        min: 1.0,
                        max: 50.0,
                        divisions: 49,
                        label: '${radius.toStringAsFixed(1)} km',
                        onChanged: (val) {
                          setState(() => _serviceRadius = val);
                        },
                        onChangeEnd: (val) => _saveRadius(val),
                      ),
                      const Text(
                        'Controls maximum driving distance from your base GPS pin for incoming job dispatches.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Verified Skills Section
                FixCard(
                  tone: FixCardTone.standard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Verified Trade Skills',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (skills.isEmpty)
                        const Text(
                          'All primary verified service categories enabled.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((skill) {
                            return Chip(
                              backgroundColor: AppColors.surfaceContainerLowest,
                              avatar: const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryEmerald,
                                size: 16,
                              ),
                              label: Text(
                                skill.categoryName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Operations Shortcuts (Earnings, KYC Documents, Partner Desk)
                FixCard(
                  tone: FixCardTone.standard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operations & Governance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingsActionTile(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Earnings & Payout Ledger',
                        subtitle: 'View completed job revenue and weekly bank settlements',
                        onTap: widget.onViewEarnings,
                      ),
                      const Divider(height: 1),
                      _SettingsActionTile(
                        icon: Icons.badge_rounded,
                        title: 'Manage KYC & Trade Credentials',
                        subtitle: 'Aadhaar, PAN, police clearance, and trade licenses',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('KYC Document Management'),
                                ),
                                body: ProviderOnboardingScreen(
                                  controller: widget.controller,
                                  pushController: widget.pushController,
                                  notificationController: widget.notificationController,
                                  onSignOut: widget.onSignOut,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsActionTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Partner Operations Helpdesk',
                        subtitle: 'Doorstep abandonment, dispute escalation & support',
                        onTap: widget.onSupportCases,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Push Notifications Card
                if (widget.pushController != null)
                  PushSettingsCard(controller: widget.pushController!),

                const SizedBox(height: AppSpacing.lg),

                // Sign Out Button
                FixButton(
                  label: 'Sign Out of Partner Account',
                  icon: Icons.logout_rounded,
                  variant: FixButtonVariant.destructive,
                  onPressed: _confirmSignOut,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          caption,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}
