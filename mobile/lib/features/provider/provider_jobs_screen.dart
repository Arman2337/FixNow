import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';

class ProviderJobsScreen extends StatelessWidget {
  const ProviderJobsScreen({
    required this.controller,
    required this.showHistory,
    super.key,
  });

  final ProviderController controller;
  final bool showHistory;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final jobs = controller.jobs.where((job) {
        final finished = {'COMPLETED', 'CANCELLED'}.contains(job.status);
        return showHistory ? finished : !finished;
      }).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixPageHeader(
              eyebrow: showHistory ? 'JOB HISTORY' : 'ACTIVE JOB',
              title: showHistory ? 'Completed work' : 'Assigned work',
              description: showHistory
                  ? 'A trustworthy record of completed and cancelled jobs.'
                  : 'Only valid actions for work assigned to your account are available.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (jobs.isEmpty)
              FixCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_history_rounded,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        showHistory
                            ? 'No completed jobs yet.'
                            : 'No active assigned job right now.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...jobs.map(
                (job) => _JobCard(
                  job: job,
                  controller: controller,
                  readOnly: showHistory,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.controller,
    required this.readOnly,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final action = switch (job.status) {
      'ASSIGNED' => ('Start journey', Icons.route_rounded),
      'EN_ROUTE' => ('Start work', Icons.home_repair_service_rounded),
      'IN_PROGRESS' => ('Complete job', Icons.task_alt_rounded),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FixCard(
        tone: FixCardTone.elevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FixStatusChip(
                label: job.status.replaceAll('_', ' '),
                icon: Icons.verified_user_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              job.description,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Job ${job.id.substring(0, 8).toUpperCase()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (!readOnly && action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FixButton(
                label: action.$1,
                icon: action.$2,
                onPressed: () => controller.advanceJob(job),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
