import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum FixButtonVariant { primary, secondary, tertiary }

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
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon case final value?) ...[
          Icon(value, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label),
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
      },
    );
  }
}
