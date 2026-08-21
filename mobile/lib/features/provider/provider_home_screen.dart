import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';

String providerServiceName(
  List<Map<String, Object?>> categories,
  String categoryId,
) {
  for (final category in categories) {
    if (category['id'] == categoryId) {
      final name = category['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
  }
  return categoryId
      .split(RegExp('[-_]'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

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
                  'Manage your availability and respond to work assigned to you.',
            ),
            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGoldSoft,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderGold),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.accentGold,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'High demand nearby · stay online for faster matching',
                      style: TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FixCard(
              tone: FixCardTone.elevated,
              semanticLabel: 'Availability ${online ? 'online' : 'offline'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FixStatusChip(
                          label: online ? 'Online' : 'Offline',
                          icon: online
                              ? Icons.online_prediction_rounded
                              : Icons.offline_bolt_rounded,
                          tone: online
                              ? FixStatusTone.success
                              : FixStatusTone.neutral,
                        ),
                      ),
                      Switch.adaptive(
                        value: online,
                        onChanged: availability == null
                            ? null
                            : (value) => controller.updateStatus(
                                value ? 'online' : 'offline',
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    online
                        ? 'Matching eligible requests in your service area.'
                        : 'Go online to receive eligible requests nearby.',
                    style: Theme.of(context).textTheme.bodyLarge,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnLightPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    availability?.weeklyRules.isEmpty ?? true
                        ? 'No recurring hours set.'
                        : 'Monday to Friday, 09:00–17:00 ${availability?.timeZone}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textOnLightSecondary,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Incoming requests',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textOnDarkPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh requests',
                  onPressed: controller.refreshingRequests
                      ? null
                      : controller.refreshRequests,
                  icon: controller.refreshingRequests
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (controller.actionError case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: FixCard(
                  tone: FixCardTone.secondary,
                  semanticLabel: 'Request action failed',
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            if (controller.requests.isEmpty)
              const FixCard(
                semanticLabel: 'No incoming requests',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: AppColors.textOnSurfaceMuted,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'No new requests',
                      style: TextStyle(
                        color: AppColors.textOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Eligible nearby jobs will appear here while you are online.',
                      style: TextStyle(color: AppColors.textOnSurfaceSecondary),
                    ),
                  ],
                ),
              )
            else
              ...controller.requests.map((request) {
                final serviceName = providerServiceName(
                  controller.categories,
                  request.serviceCategoryId,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FixCard(
                    tone: FixCardTone.elevated,
                    semanticLabel: 'Incoming service request',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FixStatusChip(
                          label: 'New request',
                          icon: Icons.radar_rounded,
                          tone: FixStatusTone.warning,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          serviceName,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          request.description,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'About ${request.distanceKm.toStringAsFixed(1)} km away',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Requested ${_requestTime(request.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Customer address and contact details appear only after you accept.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FixButton(
                          label: 'Accept request',
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: () => controller.acceptRequest(request),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Assigned work',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textOnDarkPrimary,
              ),
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
                        'No active jobs. New assignments will appear here.',
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
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          job.serviceCategoryId.replaceAll('_', ' '),
                          style: Theme.of(context).textTheme.bodySmall,
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

  static String _requestTime(DateTime value) =>
      '${value.day}/${value.month} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
