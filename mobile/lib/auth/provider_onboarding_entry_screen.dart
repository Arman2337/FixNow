import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

class ProviderOnboardingEntryScreen extends StatelessWidget {
  const ProviderOnboardingEntryScreen({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FixPageFrame(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FixBrandMark(),
              const SizedBox(height: AppSpacing.xxxl),
              const FixStatusChip(
                label: 'Profile incomplete',
                icon: Icons.pending_actions_rounded,
                tone: FixStatusTone.warning,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Your provider account is ready for setup',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Professional details, services, coverage, and verification documents are required before you can receive work.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const FixCard(
                tone: FixCardTone.secondary,
                semanticLabel: 'Provider onboarding availability',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.info),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Provider profile setup is the next planned mobile step. Your account is not verified and cannot receive jobs yet.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FixButton(
                label: 'Sign out',
                onPressed: onSignOut,
                variant: FixButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
