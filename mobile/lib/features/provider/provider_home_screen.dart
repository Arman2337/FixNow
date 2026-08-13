import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';

class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({required this.controller, super.key});
  final ProviderController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.state == ProviderLoadState.loading) {
        return const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading provider workspace',
          ),
        );
      }
      if (controller.state == ProviderLoadState.failure) {
        return FixErrorState(
          title: 'Provider workspace unavailable',
          message: controller.errorMessage!,
          onRetry: () => controller.load(verified: true),
        );
      }
      final availability = controller.availability;
      final online = availability?.status == 'online';
      final active = controller.jobs
          .where((job) => !{'COMPLETED', 'CANCELLED'}.contains(job.status))
          .toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixPageHeader(
              eyebrow: 'PROVIDER WORKSPACE',
              title: 'Ready for your next job?',
              description:
                  'Manage availability and only the work assigned to your account.',
            ),
            const SizedBox(height: AppSpacing.xl),
            FixCard(
              tone: FixCardTone.elevated,
              semanticLabel: 'Availability ${online ? 'online' : 'offline'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FixStatusChip(
                    label: online ? 'Online' : 'Offline',
                    icon: online
                        ? Icons.online_prediction_rounded
                        : Icons.offline_bolt_rounded,
                    tone: online
                        ? FixStatusTone.success
                        : FixStatusTone.neutral,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    online
                        ? 'You can receive eligible assignments.'
                        : 'You will not receive new assignments.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FixButton(
                    label: online ? 'Go offline' : 'Go online',
                    icon: online
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    variant: online
                        ? FixButtonVariant.secondary
                        : FixButtonVariant.primary,
                    onPressed: availability == null
                        ? null
                        : () => controller.updateStatus(
                            online ? 'offline' : 'online',
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FixCard(
              semanticLabel: 'Working schedule',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Working schedule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    availability?.weeklyRules.isEmpty ?? true
                        ? 'No recurring hours set.'
                        : 'Monday to Friday, 09:00–17:00 ${availability?.timeZone}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FixButton(
                    label: availability?.weeklyRules.isEmpty ?? true
                        ? 'Set weekday hours'
                        : 'Clear recurring hours',
                    icon: Icons.calendar_month_rounded,
                    variant: FixButtonVariant.secondary,
                    onPressed: availability == null
                        ? null
                        : () => controller.setWeekdaySchedule(
                            availability.weeklyRules.isEmpty,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Assigned work',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (active.isEmpty)
              const FixCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.work_history_rounded,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'No active assigned jobs. New work is not fabricated in this view.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...active.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FixCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FixStatusChip(
                          label: job.status.replaceAll('_', ' '),
                          icon: Icons.route_rounded,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          job.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Job ${job.id.substring(0, 8).toUpperCase()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
