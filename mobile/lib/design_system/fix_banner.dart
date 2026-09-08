import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum FixBannerTone { success, info, danger }

/// Branded replacement for plain [SnackBar]s: tone icon, bold title over a
/// secondary message, and a burn-down line showing time remaining. Success is
/// a quiet check (not a celebration — [AppMotion.celebrateCurve] stays
/// reserved for booking moments); danger never animates its burn-down away
/// under reduce motion because a frozen bar lies about time — there the
/// burn-down is omitted entirely.
///
/// Takes the [ScaffoldMessengerState] rather than a BuildContext so callers
/// that capture the messenger before an `await` keep working.
void showFixBanner(
  ScaffoldMessengerState messenger, {
  required String message,
  FixBannerTone tone = FixBannerTone.info,
  String? title,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorder,
          side: BorderSide(color: _toneColor(tone), width: 1),
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.accentGold,
                onPressed: onAction ?? () {},
              ),
        content: _BannerContent(
          message: message,
          title: title,
          tone: tone,
          duration: duration,
        ),
      ),
    );
}

Color _toneColor(FixBannerTone tone) => switch (tone) {
  FixBannerTone.success => AppColors.live,
  FixBannerTone.info => AppColors.primary,
  FixBannerTone.danger => AppColors.danger,
};

IconData _toneIcon(FixBannerTone tone) => switch (tone) {
  FixBannerTone.success => Icons.check_circle_rounded,
  FixBannerTone.info => Icons.info_outline_rounded,
  FixBannerTone.danger => Icons.error_outline_rounded,
};

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.message,
    required this.tone,
    required this.duration,
    this.title,
  });

  final String message;
  final String? title;
  final FixBannerTone tone;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_toneIcon(tone), color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      color: title == null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!reduceMotion) ...[
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: duration,
            curve: Curves.linear,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              color: color,
              backgroundColor: Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}
