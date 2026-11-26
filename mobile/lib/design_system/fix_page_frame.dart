import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/folding_rule_opening.dart';
import 'package:flutter/material.dart';

class FixPageFrame extends StatelessWidget {
  const FixPageFrame({required this.child, this.maxWidth = 480, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class FixPageHeader extends StatelessWidget {
  const FixPageHeader({
    required this.title,
    required this.description,
    this.eyebrow,
    super.key,
  });

  final String title;
  final String description;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow case final value?) ...[
        Text(
          value.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class FixBrandMark extends StatelessWidget {
  const FixBrandMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.sm,
    children: [
      FoldingRuleTile(size: compact ? 40 : 52, radius: compact ? 12 : 16),
      Text(
        'FixNow',
        style:
            (compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.headlineSmall)
                ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
