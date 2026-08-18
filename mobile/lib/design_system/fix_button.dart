import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum FixButtonVariant { primary, secondary, tertiary, destructive, emergency, gold }

class FixButton extends StatelessWidget {
  const FixButton({
    required this.label,
    required this.onPressed,
    this.variant = FixButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 52.0,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final FixButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

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

    final button = switch (variant) {
      FixButtonVariant.primary => FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 48, height),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
        onPressed: callback,
        child: child,
      ),
      FixButtonVariant.secondary => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 48, height),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
        onPressed: callback,
        child: child,
      ),
      FixButtonVariant.tertiary => TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 48, height),
          foregroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
        onPressed: callback,
        child: child,
      ),
      FixButtonVariant.destructive => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 48, height),
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
          minimumSize: Size(expand ? double.infinity : 48, height),
          backgroundColor: AppColors.emergency,
          foregroundColor: AppColors.textPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
        onPressed: callback,
        child: child,
      ),
      FixButtonVariant.gold => FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 48, height),
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.onAccentGold,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
        onPressed: callback,
        child: child,
      ),
    };

    return Semantics(
      button: true,
      enabled: callback != null,
      child: button,
    );
  }
}

class FixPrimaryButton extends StatelessWidget {
  const FixPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52.0,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => FixButton(
    label: label,
    onPressed: onPressed,
    variant: FixButtonVariant.primary,
    icon: icon,
    isLoading: isLoading,
    height: height,
    expand: expand,
  );
}

class FixSecondaryButton extends StatelessWidget {
  const FixSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => FixButton(
    label: label,
    onPressed: onPressed,
    variant: FixButtonVariant.secondary,
    icon: icon,
    isLoading: isLoading,
    height: height,
    expand: expand,
  );
}

class FixDangerButton extends StatelessWidget {
  const FixDangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => FixButton(
    label: label,
    onPressed: onPressed,
    variant: FixButtonVariant.destructive,
    icon: icon,
    isLoading: isLoading,
    height: height,
    expand: expand,
  );
}

class FixEmergencyButton extends StatelessWidget {
  const FixEmergencyButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.emergency_rounded,
    this.isLoading = false,
    this.height = 52.0,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => FixButton(
    label: label,
    onPressed: onPressed,
    variant: FixButtonVariant.emergency,
    icon: icon,
    isLoading: isLoading,
    height: height,
    expand: expand,
  );
}
