import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

enum FixStatusTone { neutral, success, warning, danger, info, emergency, gold }

class FixStatusChip extends StatelessWidget {
  const FixStatusChip({
    required this.label,
    required this.icon,
    this.tone = FixStatusTone.neutral,
    super.key,
  });

  final String label;
  final IconData icon;
  final FixStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      FixStatusTone.neutral => (
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
      ),
      FixStatusTone.success => (AppColors.success, AppColors.successSoft),
      FixStatusTone.warning => (AppColors.warning, AppColors.warningSoft),
      FixStatusTone.danger => (AppColors.danger, AppColors.dangerSoft),
      FixStatusTone.info => (AppColors.info, AppColors.infoSoft),
      FixStatusTone.emergency => (AppColors.emergency, AppColors.emergencySoft),
      FixStatusTone.gold => (AppColors.accentGold, AppColors.accentGoldSoft),
    };

    return Semantics(
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: tone == FixStatusTone.emergency
                  ? AppColors.emergency
                  : (tone == FixStatusTone.gold ? AppColors.borderGold : Colors.transparent),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FixVerificationBadge extends StatelessWidget {
  const FixVerificationBadge({
    this.label = 'Verified Pro',
    this.compact = false,
    super.key,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 8,
      vertical: compact ? 2 : 4,
    ),
    decoration: BoxDecoration(
      color: AppColors.successSoft,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.verified.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_rounded,
          color: AppColors.verified,
          size: compact ? 12 : 14,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.verified,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
