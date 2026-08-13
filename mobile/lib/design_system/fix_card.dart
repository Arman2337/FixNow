import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:flutter/material.dart';

enum FixCardTone { standard, secondary, elevated }

class FixCard extends StatelessWidget {
  const FixCard({
    required this.child,
    this.semanticLabel,
    this.tone = FixCardTone.standard,
    super.key,
  });

  final Widget child;
  final String? semanticLabel;
  final FixCardTone tone;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: switch (tone) {
        FixCardTone.standard => AppColors.surfacePrimary,
        FixCardTone.secondary => AppColors.surfaceSecondary,
        FixCardTone.elevated => AppColors.surfaceElevated,
      },
      shadowColor: Colors.black,
      elevation: tone == FixCardTone.elevated ? 8 : 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );
    return semanticLabel == null
        ? card
        : Semantics(container: true, label: semanticLabel, child: card);
  }
}
