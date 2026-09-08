import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

/// Horizontal interactive journey progress line for active booking states.
///
/// Maps the backend booking lifecycle to 5 clear customer stages:
/// 1. Booked -> 2. Matched -> 3. En Route -> 4. In Progress -> 5. Done.
/// Features smooth interpolation, step badges, and an ambient live pulse.
class FixJourneyProgressLine extends StatelessWidget {
  const FixJourneyProgressLine({
    required this.currentStatus,
    this.onStepTapped,
    super.key,
  });

  final String currentStatus;
  final ValueChanged<int>? onStepTapped;

  static const stages = [
    (key: 'REQUESTED', label: 'Booked'),
    (key: 'ASSIGNED', label: 'Matched'),
    (key: 'EN_ROUTE', label: 'En Route'),
    (key: 'IN_PROGRESS', label: 'Work'),
    (key: 'COMPLETED', label: 'Done'),
  ];

  int get currentIndex {
    final status = currentStatus.toUpperCase();
    return switch (status) {
      'REQUESTED' => 0,
      'ASSIGNED' || 'ACCEPTED' => 1,
      'EN_ROUTE' || 'ARRIVED' || 'OTP_VERIFIED' => 2,
      'IN_PROGRESS' => 3,
      'COMPLETED' => 4,
      _ => 0,
    };
  }

  double get progressFraction {
    final index = currentIndex;
    if (index <= 0) return 0.12;
    if (index >= stages.length - 1) return 1.0;
    return (index + 0.5) / stages.length;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activeIndex = currentIndex;
    final targetFraction = progressFraction;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track line with animated fill
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              if (reduceMotion)
                FractionallySizedBox(
                  widthFactor: targetFraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeIndex == 4 ? AppColors.success : AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                )
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: targetFraction),
                  duration: AppMotion.container,
                  curve: AppMotion.enterCurve,
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              activeIndex >= 2 ? AppColors.live : AppColors.primaryHover,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Stage labels & indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < stages.length; i++)
                GestureDetector(
                  onTap: onStepTapped != null ? () => onStepTapped!(i) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepDot(
                        isPassed: i < activeIndex,
                        isCurrent: i == activeIndex,
                        reduceMotion: reduceMotion,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stages[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: i == activeIndex ? FontWeight.w700 : FontWeight.w500,
                          color: i == activeIndex
                              ? AppColors.cream
                              : (i < activeIndex
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.isPassed,
    required this.isCurrent,
    required this.reduceMotion,
  });

  final bool isPassed;
  final bool isCurrent;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (isPassed) {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 10,
          color: AppColors.cream,
        ),
      );
    }

    if (isCurrent) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.live,
          shape: BoxShape.circle,
          boxShadow: reduceMotion
              ? null
              : [
                  BoxShadow(
                    color: AppColors.live.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: const Center(
          child: SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.borderStrong.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
