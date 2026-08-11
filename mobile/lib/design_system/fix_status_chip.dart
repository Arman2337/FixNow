import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

enum FixStatusTone { neutral, success, warning, danger, info }

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
    };

    return Semantics(
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
