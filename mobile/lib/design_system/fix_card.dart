import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';

enum FixCardTone { standard, secondary, elevated, emergency, gold, cream }

class FixCard extends StatelessWidget {
  const FixCard({
    required this.child,
    this.semanticLabel,
    this.tone = FixCardTone.standard,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.borderColor,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final String? semanticLabel;
  final FixCardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final usesLightSurface = switch (tone) {
      FixCardTone.standard || FixCardTone.secondary || FixCardTone.cream || FixCardTone.gold || FixCardTone.emergency => true,
      FixCardTone.elevated => false,
    };
    final bgColor = switch (tone) {
      FixCardTone.standard => AppColors.surfacePrimary,
      FixCardTone.secondary => AppColors.surfaceSecondary,
      FixCardTone.elevated => AppColors.surfaceElevated,
      FixCardTone.emergency => AppColors.emergencySoft,
      FixCardTone.gold => AppColors.accentGoldSoft,
      FixCardTone.cream => AppColors.cream,
    };

    final effectiveBorderColor = borderColor ?? switch (tone) {
      FixCardTone.emergency => AppColors.emergency,
      FixCardTone.gold => AppColors.borderGold,
      _ => AppColors.borderDefault,
    };

    final radius = borderRadius ?? AppRadius.cardBorder;

    final foreground = usesLightSurface
        ? AppColors.textOnSurface
        : AppColors.textPrimary;
    final supporting = usesLightSurface
        ? AppColors.textOnSurfaceSecondary
        : AppColors.textSecondary;

    final content = Theme(
      data: Theme.of(context).copyWith(
        textTheme: AppTypography.textTheme(foreground, supporting),
      ),
      child: IconTheme(
        data: IconThemeData(color: foreground),
        // A light card sits inside the app's dark theme. Use a complete
        // DefaultTextStyle rather than merging with the page's white default;
        // otherwise plain Text widgets can inherit white text on this surface.
        child: DefaultTextStyle(
          style: TextStyle(color: foreground),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final card = Card(
      color: bgColor,
      shadowColor: Colors.black,
      elevation: tone == FixCardTone.elevated ? 8 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: effectiveBorderColor,
          width: tone == FixCardTone.emergency ? 1.5 : 1.0,
        ),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: content,
            )
          : content,
    );

    // Tappable cards get a subtle press-in scale to match buttons; static
    // cards are untouched.
    final pressable = onTap == null ? card : FixPressable(child: card);

    return semanticLabel == null
        ? pressable
        : Semantics(container: true, label: semanticLabel, child: pressable);
  }
}
