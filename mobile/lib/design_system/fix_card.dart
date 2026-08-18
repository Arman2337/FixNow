import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
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

    final content = Padding(
      padding: padding,
      child: child,
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

    return semanticLabel == null
        ? card
        : Semantics(container: true, label: semanticLabel, child: card);
  }
}
