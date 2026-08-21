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
    this.onSupportCases,
    super.key,
  });
  final ProviderController controller;
  final VoidCallback onSignOut;
  final VoidCallback? onSupportCases;

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
          final profileComplete = controller.profile != null;
          final skillsComplete = controller.skills.isNotEmpty;
          final reviewedDocuments = controller.documents
              .where((document) => document.status.toUpperCase() == 'APPROVED')
              .length;
          final documentsComplete = reviewedDocuments > 0;
          final completedSteps = [
            profileComplete,
            skillsComplete,
            documentsComplete,
          ].where((complete) => complete).length;
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
                    FixCard(
                      tone: FixCardTone.secondary,
                      child: Text(
                        reason,
                        style: const TextStyle(color: AppColors.textOnSurface),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _SetupProgress(completedSteps: completedSteps),
                  const SizedBox(height: AppSpacing.lg),
                  _Step(
                    step: 1,
                    title: 'Professional profile',
                    complete: profileComplete,
                    detail: !profileComplete
                        ? 'Name, bio and service radius are required.'
                        : controller.profile!.displayName,
                  ),
                  _Step(
                    step: 2,
                    title: 'Services and skills',
                    complete: skillsComplete,
                    detail: skillsComplete
                        ? '${controller.skills.length} service ${controller.skills.length == 1 ? 'selected' : 'services selected'}.'
                        : 'Add only services you are qualified to provide.',
                  ),
                  _Step(
                    step: 3,
                    title: 'Identity documents',
                    complete: documentsComplete,
                    detail: documentsComplete
                        ? '$reviewedDocuments private ${reviewedDocuments == 1 ? 'document approved' : 'documents approved'}.'
                        : _documentDetail(controller.documents),
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
                  if (onSupportCases != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    FixButton(
                      label: 'Support Cases',
                      onPressed: onSupportCases,
                      variant: FixButtonVariant.secondary,
                    ),
                  ],
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
      "You're verified!",
      'Your FixNow provider account has been approved. You can now go online and receive eligible requests.',
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

  static String _documentDetail(List<ProviderDocument> documents) {
    if (documents.isEmpty) {
      return 'Private upload is available after profile setup; files are never shown publicly.';
    }
    final statuses = documents
        .map((document) => document.status.toLowerCase().replaceAll('_', ' '))
        .toSet()
        .join(', ');
    return '${documents.length} private ${documents.length == 1 ? 'document' : 'documents'} submitted ($statuses).';
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.title,
    required this.complete,
    required this.detail,
  });
  final int step;
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
          CircleAvatar(
            radius: 16,
            backgroundColor: complete
                ? AppColors.success
                : AppColors.backgroundSecondary,
            child: complete
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.textOnDarkPrimary,
                  )
                : Text(
                    '$step',
                    style: const TextStyle(
                      color: AppColors.textOnDarkSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textOnSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnSurfaceSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.completedSteps});

  final int completedSteps;

  @override
  Widget build(BuildContext context) => FixCard(
    tone: FixCardTone.secondary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Setup progress',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textOnSurface),
            ),
            Text(
              '$completedSteps of 3 complete',
              style: const TextStyle(
                color: AppColors.textOnSurfaceSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LinearProgressIndicator(
          value: completedSteps / 3,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.success,
          backgroundColor: AppColors.borderDefault,
        ),
      ],
    ),
  );
}
