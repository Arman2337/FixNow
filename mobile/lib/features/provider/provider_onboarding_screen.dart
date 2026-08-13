import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_setup_screen.dart';
import 'package:flutter/material.dart';

class ProviderOnboardingScreen extends StatelessWidget {
  const ProviderOnboardingScreen({
    required this.controller,
    required this.onSignOut,
    super.key,
  });
  final ProviderController controller;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.state == ProviderLoadState.loading) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading provider setup',
              ),
            );
          }
          if (controller.state == ProviderLoadState.failure) {
            return FixErrorState(
              title: 'Provider setup unavailable',
              message: controller.errorMessage!,
              onRetry: () => controller.load(verified: false),
            );
          }
          final status =
              controller.application?.status ??
              ProviderApplicationStatus.unverified;
          final copy = _copy(status);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: FixPageFrame(
              maxWidth: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FixBrandMark(),
                  const SizedBox(height: AppSpacing.xxl),
                  FixStatusChip(label: copy.$1, icon: copy.$2, tone: copy.$3),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    copy.$4,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    copy.$5,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (controller.application?.reason case final reason?) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FixCard(tone: FixCardTone.secondary, child: Text(reason)),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _Step(
                    title: 'Professional profile',
                    complete: controller.profile != null,
                    detail: controller.profile == null
                        ? 'Name, bio and service radius are required.'
                        : controller.profile!.displayName,
                  ),
                  const _Step(
                    title: 'Services and skills',
                    complete: false,
                    detail: 'Add only services you are qualified to provide.',
                  ),
                  const _Step(
                    title: 'Identity documents',
                    complete: false,
                    detail:
                        'Private upload is available after profile setup; files are never shown publicly.',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FixButton(
                    label: controller.profile == null
                        ? 'Start professional setup'
                        : 'Continue professional setup',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProviderSetupScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FixButton(
                    label: 'Sign out',
                    onPressed: onSignOut,
                    variant: FixButtonVariant.secondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  static (String, IconData, FixStatusTone, String, String) _copy(
    ProviderApplicationStatus status,
  ) => switch (status) {
    ProviderApplicationStatus.underReview => (
      'Under review',
      Icons.fact_check_rounded,
      FixStatusTone.info,
      'Your application is being reviewed',
      'You cannot go online until an authorized reviewer approves your application.',
    ),
    ProviderApplicationStatus.approved => (
      'Verified',
      Icons.verified_rounded,
      FixStatusTone.success,
      'Your provider account is approved',
      'Sign in again to refresh your verified-provider access and open the workspace.',
    ),
    ProviderApplicationStatus.rejected => (
      'Not approved',
      Icons.cancel_outlined,
      FixStatusTone.danger,
      'Your application was not approved',
      'Review the decision below. No verification claim is shown.',
    ),
    ProviderApplicationStatus.resubmissionRequested => (
      'Action required',
      Icons.edit_document,
      FixStatusTone.warning,
      'Update and resubmit your details',
      'A reviewer requested corrections before another review.',
    ),
    _ => (
      'Profile incomplete',
      Icons.pending_actions_rounded,
      FixStatusTone.warning,
      'Build your professional profile',
      'Complete supported profile, services, coverage, and private document steps before review.',
    ),
  };
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.complete,
    required this.detail,
  });
  final String title;
  final bool complete;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: FixCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: complete ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
