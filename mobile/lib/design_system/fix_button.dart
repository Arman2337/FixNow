import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum FixButtonVariant { primary, secondary, tertiary, destructive, emergency }

class FixButton extends StatelessWidget {
  const FixButton({
    required this.label,
    required this.onPressed,
    this.variant = FixButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final FixButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final child = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (isLoading)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon case final value?)
          Icon(value, size: 20),
        Text(label, textAlign: TextAlign.center),
      ],
    );

    return Semantics(
      button: true,
      enabled: callback != null,
      child: switch (variant) {
        FixButtonVariant.primary => FilledButton(
          onPressed: callback,
          child: child,
        ),
        FixButtonVariant.secondary => OutlinedButton(
          onPressed: callback,
          child: child,
        ),
        FixButtonVariant.tertiary => TextButton(
          onPressed: callback,
          child: child,
        ),
        FixButtonVariant.destructive => OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonBorder,
            ),
          ),
          onPressed: callback,
          child: child,
        ),
        FixButtonVariant.emergency => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emergency,
            foregroundColor: AppColors.textPrimary,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonBorder,
            ),
          ),
          onPressed: callback,
          child: child,
        ),
      },
    );
  }
}
