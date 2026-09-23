import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_schedule_hours_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
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
  const ProviderHomeScreen({
    required this.controller,
    this.chatRepository,
    this.callRepository,
    this.loadAcceptTime,
    this.onViewEarnings,
    this.notificationController,
    this.onTechDesk,
    this.onOpenBooking,
    this.onOpenInvoice,
    super.key,
  });
  final ProviderController controller;
  final ChatRepository? chatRepository;
  final dynamic callRepository;

  /// FN-111: loads this provider's rolling accept-time signal; null hides
  /// the card entirely (including failures and insufficient data).
  final Future<ProviderAcceptTime?> Function()? loadAcceptTime;

  /// FN-053: opens the earnings ledger; null hides the entry point.
  final VoidCallback? onViewEarnings;

  final NotificationController? notificationController;
  final VoidCallback? onTechDesk;
  final void Function(String bookingId)? onOpenBooking;
  final void Function(InAppNotification notification)? onOpenInvoice;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: notificationController == null
        ? controller
        : Listenable.merge([controller, notificationController!]),
    builder: (context, _) {
      final requestsSectionKey = GlobalKey();
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
      return RefreshIndicator(
        color: AppColors.accentGold,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {
          await controller.refreshRequests();
          await controller.load(verified: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FixPageHeader(
                      eyebrow: 'PROVIDER WORKSPACE',
                      title: 'Ready for your next job?',
                      description:
                          'Manage your availability and respond to work assigned to you.',
                    ),
                  ),
                  if (notificationController != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    FixNotificationBellIcon(
                      controller: notificationController!,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationCenterScreen(
                              controller: notificationController!,
                              onOpenBooking: onOpenBooking,
                              onOpenInvoice: onOpenInvoice,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (notificationController != null &&
                  notificationController!.notifications.any(
                    (n) => !n.isRead,
                  )) ...[
                Builder(
                  builder: (context) {
                    final unread = notificationController!.notifications
                        .firstWhere((n) => !n.isRead);
                    return _ProviderNotificationBanner(
                      notification: unread,
                      onTap: () {
                        notificationController!.markAsRead(unread.id);
                        if (unread.category == NotificationCategory.payments) {
                          onOpenInvoice?.call(unread);
                        } else if (unread.bookingId != null) {
                          onOpenBooking?.call(unread.bookingId!);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NotificationCenterScreen(
                                controller: notificationController!,
                                onOpenBooking: onOpenBooking,
                                onOpenInvoice: onOpenInvoice,
                              ),
                            ),
                          );
                        }
                      },
                      onDismiss: () {
                        notificationController!.markAsRead(unread.id);
                      },
                    );
                  },
                ),
              ],

              if (controller.requests.isNotEmpty)
                _IncomingRequestBanner(
                  count: controller.requests.length,
                  firstRequest: controller.requests.first,
                  onTap: () {
                    final targetContext = requestsSectionKey.currentContext;
                    if (targetContext != null) {
                      Scrollable.ensureVisible(
                        targetContext,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),

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
                      color: Color(0xFF92400E),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'High demand nearby · stay online for faster matching',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                              : (value) async {
                                  final newStatus = value
                                      ? 'online'
                                      : 'offline';
                                  await controller.updateStatus(newStatus);
                                  if (context.mounted) {
                                    showFixBanner(
                                      ScaffoldMessenger.of(context),
                                      message: value
                                          ? 'You are now online. Receiving eligible jobs in your area.'
                                          : 'You are now offline. Go online to receive customer requests.',
                                      tone: value
                                          ? FixBannerTone.success
                                          : FixBannerTone.info,
                                    );
                                  }
                                },
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
              if (loadAcceptTime != null)
                _AcceptTimeCard(load: loadAcceptTime!),
              const SizedBox(height: AppSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: availability == null
                            ? null
                            : () => FixProviderWorkingHoursSheet.show(
                                context,
                                controller: controller,
                              ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                availability?.timingSummary ?? 'No schedule set',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Edit\nSchedule',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onViewEarnings != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: InkWell(
                          onTap: onViewEarnings,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Builder(
                                  builder: (context) {
                                    final earnings = controller.profile?.stats?.earningsMinor ?? 0;
                                    final amount = (earnings ~/ 100).toString();
                                    return Text(
                                      '₹$amount',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'View\nEarnings',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            height: 1.2,
                                          ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                key: requestsSectionKey,
                children: [
                  Expanded(
                    child: Text(
                      'Incoming requests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
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
                        style: TextStyle(
                          color: AppColors.textOnSurfaceSecondary,
                        ),
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
                            onPressed: () async {
                              await controller.acceptRequest(request);
                              if (context.mounted) {
                                showFixBanner(
                                  ScaffoldMessenger.of(context),
                                  message:
                                      'Request accepted! Preparing active job details.',
                                  tone: FixBannerTone.success,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Assigned work',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
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
                    child: InkWell(
                      key: Key('active_job_${job.id}'),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProviderActiveJobCockpitScreen(
                            job: job,
                            controller: controller,
                            chatRepository: chatRepository,
                          ),
                        ),
                      ),
                      child: FixCard(
                        tone: FixCardTone.elevated,
                        borderColor: AppColors.borderGold,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                FixStatusChip(
                                  label: job.status.replaceAll('_', ' '),
                                  icon: Icons.route_rounded,
                                  tone: job.status == 'IN_PROGRESS'
                                      ? FixStatusTone.warning
                                      : FixStatusTone.info,
                                ),
                                const Row(
                                  children: [
                                    Text(
                                      'Open Cockpit',
                                      style: TextStyle(
                                        color: AppColors.accentGold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: AppColors.accentGold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              job.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                const Icon(
                                  Icons.handyman_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    providerServiceName(
                                      controller.categories,
                                      job.serviceCategoryId,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Scheduled: ${_requestTime(job.scheduledAt ?? job.createdAt)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Job #${job.id.replaceAll('-', '').substring(0, 8).toUpperCase()}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Tap to update status / OTP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  static String _requestTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// FN-111: honest "your usual accept time" signal. Renders nothing while
/// loading, on failure, or when FixNow lacks enough accepted jobs.
class _AcceptTimeCard extends StatefulWidget {
  const _AcceptTimeCard({required this.load});
  final Future<ProviderAcceptTime?> Function() load;

  @override
  State<_AcceptTimeCard> createState() => _AcceptTimeCardState();
}

class _AcceptTimeCardState extends State<_AcceptTimeCard> {
  late final Future<ProviderAcceptTime?> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<ProviderAcceptTime?>(
    future: _future,
    builder: (context, snapshot) {
      final signal = snapshot.data;
      if (signal?.averageAcceptMinutes is! int) {
        return const SizedBox.shrink();
      }
      final minutes = signal!.averageAcceptMinutes!;
      return FixCard(
        tone: FixCardTone.secondary,
        semanticLabel: 'Your usual accept time',
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Your usual accept time is about $minutes min, from '
                '${signal.sampleSize} accepted jobs in the last '
                '${signal.windowDays} days.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ProviderNotificationBanner extends StatelessWidget {
  const _ProviderNotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = notification.category.color;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    notification.category.icon,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            notification.category ==
                                    NotificationCategory.payments
                                ? 'View Invoice'
                                : notification.bookingId != null
                                ? 'View Booking'
                                : 'View Details',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Dismiss notification',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingRequestBanner extends StatelessWidget {
  const _IncomingRequestBanner({
    required this.count,
    required this.firstRequest,
    required this.onTap,
  });

  final int count;
  final ProviderRequest firstRequest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    size: 18,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              count == 1
                                  ? 'New Request Available!'
                                  : '$count New Requests Available!',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACTION NEEDED',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${firstRequest.distanceKm.toStringAsFixed(1)} km away · Tap to review and accept',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.accentGold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
