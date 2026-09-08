import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

enum FixStatusTone { neutral, success, warning, danger, info, emergency, gold, live }

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

  /// (foreground, background) per tone. Foregrounds use the `…OnLight` accent
  /// steps so every pair holds WCAG 4.5:1 on its Soft background — asserted in
  /// design_system_test.dart.
  static (Color, Color) colorsFor(FixStatusTone tone) => switch (tone) {
    FixStatusTone.neutral => (
      AppColors.textOnLightSecondary,
      AppColors.surfaceSecondary,
    ),
    FixStatusTone.success => (AppColors.successOnLight, AppColors.successSoft),
    FixStatusTone.warning => (AppColors.warningOnLight, AppColors.warningSoft),
    FixStatusTone.danger => (AppColors.dangerOnLight, AppColors.dangerSoft),
    FixStatusTone.info => (AppColors.infoOnLight, AppColors.infoSoft),
    FixStatusTone.emergency => (
      AppColors.dangerOnLight,
      AppColors.emergencySoft,
    ),
    FixStatusTone.gold => (AppColors.ratingOnLight, AppColors.accentGoldSoft),
    // Filled chip: green text on a light-soft background would fail contrast,
    // so live inverts — dark foreground on the live green (8.5:1).
    FixStatusTone.live => (AppColors.backgroundPrimary, AppColors.live),
  };

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = colorsFor(tone);

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
      border: Border.all(color: AppColors.successOnLight.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_rounded,
          color: AppColors.successOnLight,
          size: compact ? 12 : 14,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.successOnLight,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
