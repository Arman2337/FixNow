import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onGetStarted,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FixPageFrame(
            maxWidth: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.xl * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FixBrandMark(),
                  ),
                  SizedBox(height: constraints.maxHeight < 700 ? 56 : 104),
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Trusted help.\nWhen you need it.',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Book reliable local professionals and follow every service update with confidence.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  FixButton(label: 'Get started', onPressed: onGetStarted),
                  const SizedBox(height: AppSpacing.sm),
                  FixButton(
                    label: 'Sign in',
                    onPressed: onSignIn,
                    variant: FixButtonVariant.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
