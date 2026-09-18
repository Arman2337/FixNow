import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Provider Jobs & Schedule Ledger
/// Reconstructed to match Stitch blueprint FixNow_-_Provider_Jobs___Schedule_Ledger.html
class ProviderJobsScreen extends StatefulWidget {
  const ProviderJobsScreen({
    required this.controller,
    required this.showHistory,
    this.chatRepository,
    super.key,
  });

  final ProviderController controller;
  final bool showHistory;
  final ChatRepository? chatRepository;

  @override
  State<ProviderJobsScreen> createState() => _ProviderJobsScreenState();
}

class _ProviderJobsScreenState extends State<ProviderJobsScreen> {
  late bool _showHistory = widget.showHistory;
  int _selectedDayIndex = 0;

  @override
  void didUpdateWidget(covariant ProviderJobsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showHistory != widget.showHistory) {
      _showHistory = widget.showHistory;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final allJobs = widget.controller.jobs;
      final assignedJobs = allJobs
          .where((j) => !{'COMPLETED', 'CANCELLED'}.contains(j.status))
          .toList();
      final historyJobs = allJobs
          .where((j) => {'COMPLETED', 'CANCELLED'}.contains(j.status))
          .toList();

      final currentJobs = _showHistory ? historyJobs : assignedJobs;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider Profile & Status Banner
            _buildProviderProfileAndStatus(),
            const SizedBox(height: AppSpacing.md),

            // Top Emergency On-Call Banner (Stitch blueprint)
            _buildEmergencyOnCallBanner(),
            const SizedBox(height: AppSpacing.md),

            // Horizontal Date Strip with Job Density Indicators
            _buildDateStrip(assignedJobs.length),
            const SizedBox(height: AppSpacing.md),

            // Tabbed Switcher: Assigned Jobs vs Completed History
            _buildTabSwitcher(assignedJobs.length, historyJobs.length),
            const SizedBox(height: AppSpacing.md),

            // Working Radius Shortcut
            _buildWorkingRadiusShortcut(),
            const SizedBox(height: AppSpacing.md),

            // Header info removed (not in Stitch reference)

            // Content Container
            if (currentJobs.isEmpty)
              FixCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.work_history_rounded,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _showHistory
                              ? 'No completed jobs yet.'
                              : 'No active assigned job right now.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_showHistory) ...[
              _buildHistorySummaryPill(historyJobs),
              const SizedBox(height: AppSpacing.md),
              ...historyJobs.map(
                (job) =>
                    _HistoryJobCard(job: job, controller: widget.controller),
              ),
            ] else ...[
              // Assigned Jobs: Top Urgent Next Job Card first
              _TopUrgentJobCard(
                job: assignedJobs.first,
                controller: widget.controller,
                chatRepository: widget.chatRepository,
              ),
              // Subsequent upcoming jobs
              if (assignedJobs.length > 1) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Upcoming Dispatches',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...assignedJobs
                    .skip(1)
                    .map(
                      (job) => _UpcomingJobCard(
                        job: job,
                        controller: widget.controller,
                        chatRepository: widget.chatRepository,
                      ),
                    ),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      );
    },
  );

  Widget _buildProviderProfileAndStatus() {
    final availability = widget.controller.availability;
    final online = availability?.status == 'online';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.controller.profile?.displayName ??
                                  'Provider',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                      Text(
                        '${widget.controller.skills.isNotEmpty ? widget.controller.skills.take(2).map((s) => s.categoryName).join(' & ') : 'Service Professional'} • FixNow Pro',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              final newStatus = online ? 'offline' : 'online';
              await widget.controller.updateStatus(newStatus);
            },
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: online
                    ? AppColors.primaryFixed
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (online) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    online ? 'ON DUTY' : 'STANDBY',
                    style: TextStyle(
                      color: online
                          ? AppColors.onPrimaryFixed
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyOnCallBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: AppColors.accentGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Emergency On-Call Active',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '1.5x Pay Rate',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accentGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip(int activeJobCount) {
    final now = DateTime.now();
    final days = List.generate(5, (i) => now.add(Duration(days: i)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(days.length, (index) {
          final isSelected = _selectedDayIndex == index;
          final date = days[index];
          final label = index == 0
              ? 'TODAY'
              : index == 1
              ? 'TOM'
              : _weekdayShort(date.weekday);

          return Padding(
            padding: EdgeInsets.only(right: index < days.length - 1 ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedDayIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primaryFixed
                                : (index == 0 && activeJobCount > 0)
                                ? AppColors.primary
                                : AppColors.borderStrong,
                          ),
                        ),
                        if (index == 0 && activeJobCount > 1) ...[
                          const SizedBox(width: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primaryFixed
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabSwitcher(int assignedCount, int historyCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _showHistory = false),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_showHistory
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_showHistory
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Assigned Jobs ($assignedCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: !_showHistory
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: !_showHistory
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _showHistory = true),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _showHistory
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _showHistory
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Completed History ($historyCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _showHistory
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: _showHistory
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingRadiusShortcut() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Working Hours & 8 km Radius',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: const [
              Text(
                '09:00 - 19:30',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySummaryPill(List<CustomerBooking> history) {
    final completedCount = history.where((j) => j.status == 'COMPLETED').length;
    final cancelledCount = history.where((j) => j.status == 'CANCELLED').length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DISPATCH ARCHIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$completedCount Resolved',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${history.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$cancelledCount Cancelled',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top Urgent Next Job Card (Hero composition from Stitch blueprint)
class _TopUrgentJobCard extends StatelessWidget {
  const _TopUrgentJobCard({
    required this.job,
    required this.controller,
    this.chatRepository,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final ChatRepository? chatRepository;

  @override
  Widget build(BuildContext context) {
    final action = switch (job.status) {
      'ASSIGNED' => ('Start journey', Icons.navigation_rounded),
      'EN_ROUTE' => ('Verify OTP to start', Icons.lock_open_rounded),
      'IN_PROGRESS' => ('Complete job', Icons.task_alt_rounded),
      _ => null,
    };

    final isEnRoute = job.status == 'EN_ROUTE';
    final isInProgress = job.status == 'IN_PROGRESS';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnRoute ? AppColors.errorContainer : AppColors.border,
          width: isEnRoute ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Priority Banner (Stitch blueprint)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            color: isEnRoute
                ? AppColors.errorContainer
                : AppColors.surfaceContainerHigh,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEnRoute ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEnRoute
                          ? 'Priority Dispatch • En Route'
                          : isInProgress
                          ? 'In Progress • Service Active'
                          : 'Assigned • Ready for Dispatch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isEnRoute
                            ? AppColors.dangerOnLight
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  isEnRoute ? 'ETA 7 MINS' : job.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isEnRoute
                        ? AppColors.dangerOnLight
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Job ID & Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'JOB #${_shortId(job.id)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            providerServiceName(
                              controller.categories,
                              job.serviceCategoryId,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.handyman_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Customer Cardlet (Removed fake VIP info)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Center(
                              child: Text(
                                'CU',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Available upon arrival',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () async {
                          final opened = await openCustomerNavigation(job);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not open maps. Check that a maps app is installed and the booking has a service address.',
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.near_me_rounded,
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Navigate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Address Line / Coordinates
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (job.locationLatitude != null &&
                                job.locationLongitude != null)
                            ? 'Coordinates: ${job.locationLatitude!.toStringAsFixed(4)}, ${job.locationLongitude!.toStringAsFixed(4)}'
                            : 'Customer service location on record',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Map Snippet Container
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.surfaceContainerHigh,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ProviderLiveMap(
                          showOverlay: false,
                          route: controller.currentRoute,
                          customerLocation: (job.locationLatitude != null &&
                                  job.locationLongitude != null)
                              ? CustomerMapLocation(
                                  latitude: job.locationLatitude!,
                                  longitude: job.locationLongitude!,
                                )
                              : null,
                          providerLocation: controller.currentLocation,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.fullscreen_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Primary Actions Row: Action Button + Call & Chat shortcuts
                Row(
                  children: [
                    if (action != null)
                      Expanded(
                        flex: 2,
                        child: FixButton(
                          label: action.$1,
                          icon: action.$2,
                          trailingIcon: Icons.arrow_forward_rounded,
                          onPressed: () async {
                            if (job.status == 'EN_ROUTE') {
                              final otp = await _requestServiceStartOtp(
                                context,
                              );
                              if (otp != null) {
                                await controller.verifyOtpAndStartJob(job, otp);
                              }
                              return;
                            }
                            if (job.status == 'IN_PROGRESS') {
                              if (!JobProofRepository.instance.hasProof(
                                job.id,
                              )) {
                                await JobProofVerificationDialog.show(
                                  context,
                                  bookingId: job.id,
                                );
                              }
                              await controller.advanceJob(job);
                              return;
                            }
                            await controller.advanceJob(job);
                          },
                        ),
                      ),
                    if (chatRepository != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FixButton(
                          label: 'Chat',
                          icon: Icons.chat_bubble_rounded,
                          variant: FixButtonVariant.secondary,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookingChatScreen(
                                controller: ChatController(
                                  repository: chatRepository!,
                                  bookingId: job.id,
                                  realtimeClient: controller.realtime,
                                  isProvider: true,
                                ),
                                providerName: 'Customer',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (job.status == 'ASSIGNED' ||
                        job.status == 'EN_ROUTE' ||
                        job.status == 'IN_PROGRESS') ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FixButton(
                          label: 'Call',
                          icon: Icons.call_rounded,
                          variant: FixButtonVariant.secondary,
                          onPressed: () {
                            if (job.customerPhone != null) {
                              const CallController().launchCall(job.customerPhone!);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone number unavailable')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Open Full Job Cockpit Button
                FixButton(
                  label: 'Open Full Job Cockpit',
                  icon: Icons.dashboard_customize_rounded,
                  trailingIcon: Icons.arrow_forward_rounded,
                  variant: FixButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProviderActiveJobCockpitScreen(
                        job: job,
                        controller: controller,
                        chatRepository: chatRepository,
                      ),
                    ),
                  ),
                ),

                // Job Proof Viewer Card
                if (JobProofRepository.instance.getProof(job.id)
                    case final proof?) ...[
                  const SizedBox(height: AppSpacing.md),
                  JobProofViewerCard(proof: proof),
                ],

                // Verification Photos (for in-progress)
                if (job.status == 'IN_PROGRESS') ...[
                  const SizedBox(height: AppSpacing.sm),
                  FixButton(
                    label: 'Verification Photos',
                    icon: Icons.camera_alt_outlined,
                    variant: FixButtonVariant.secondary,
                    onPressed: () => JobProofVerificationDialog.show(
                      context,
                      bookingId: job.id,
                      initialProof: JobProofRepository.instance.getProof(
                        job.id,
                      ),
                    ),
                  ),
                ],

                // Live Tracking Block (for en-route)
                if (isEnRoute) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LiveTrackingBlock(job: job, controller: controller),
                  const SizedBox(height: AppSpacing.md),
                  FixButton(
                    label: controller.locationSharing[job.id] == true
                        ? 'Stop sharing'
                        : 'Share location',
                    icon: controller.locationSharing[job.id] == true
                        ? Icons.cancel_outlined
                        : Icons.my_location_rounded,
                    variant: FixButtonVariant.secondary,
                    onPressed: () => controller.setLocationConsent(
                      job,
                      controller.locationSharing[job.id] != true,
                    ),
                  ),
                  if (controller.actionError case final message?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                ],

                // Cancellation Button
                if (const {'ASSIGNED', 'EN_ROUTE'}.contains(job.status)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CancelJobButton(job: job, controller: controller),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming Job Card for subsequent assigned jobs
class _UpcomingJobCard extends StatelessWidget {
  const _UpcomingJobCard({
    required this.job,
    required this.controller,
    this.chatRepository,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final ChatRepository? chatRepository;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JOB #${_shortId(job.id)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  job.status.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerServiceName(
                        controller.categories,
                        job.serviceCategoryId,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_category(job.serviceCategoryId)} • ${_date(job.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.checklist_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Standard Checklist',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderActiveJobCockpitScreen(
                      job: job,
                      controller: controller,
                      chatRepository: chatRepository,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Job Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// History Job Card
class _HistoryJobCard extends StatelessWidget {
  const _HistoryJobCard({required this.job, required this.controller});

  final CustomerBooking job;
  final ProviderController controller;

  @override
  Widget build(BuildContext context) {
    final isCompleted = job.status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FX-${_shortId(job.id)} • ${_date(job.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.primarySoft
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted ? 'Resolved' : job.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isCompleted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_category(job.serviceCategoryId)} • Rating ★ 5.0',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (JobProofRepository.instance.getProof(job.id)
              case final proof?) ...[
            const SizedBox(height: AppSpacing.sm),
            JobProofViewerCard(proof: proof),
          ],
        ],
      ),
    );
  }
}


String _weekdayShort(int weekday) => switch (weekday) {
  1 => 'MON',
  2 => 'TUE',
  3 => 'WED',
  4 => 'THU',
  5 => 'FRI',
  6 => 'SAT',
  _ => 'SUN',
};

String _category(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _shortId(String value) {
  final compact = value.replaceAll('-', '');
  final short = compact.length <= 8 ? compact : compact.substring(0, 8);
  return short.toUpperCase();
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

class _LiveTrackingBlock extends StatelessWidget {
  const _LiveTrackingBlock({required this.job, required this.controller});

  final CustomerBooking job;
  final ProviderController controller;

  @override
  Widget build(BuildContext context) {
    final sharing = controller.locationSharing[job.id] == true;
    final published = controller.locationPublished[job.id] == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE TRACKING',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              if (sharing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Sharing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                sharing
                    ? Icons.location_on_rounded
                    : Icons.location_off_outlined,
                color: sharing ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  sharing
                      ? 'Location sharing active'
                      : 'Location sharing is off',
                  style: TextStyle(
                    color: sharing
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            published
                ? 'Location shared successfully. Send an update when your position changes.'
                : sharing
                ? 'The customer can follow your arrival after your first update.'
                : 'Share your location while travelling so the customer can follow your arrival.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

Future<String?> _requestServiceStartOtp(BuildContext context) async {
  final input = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.accentGold,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Verify customer OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textOnDarkPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Ask the customer for the 4-digit code shown in their FixNow booking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textOnDarkSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Customer OTP',
                style: TextStyle(
                  color: AppColors.textOnDarkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setDialogState(() {}),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: '• • • •',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: AppColors.inputHint,
                    letterSpacing: 4,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${input.text.length}/4 digits',
                  style: const TextStyle(color: AppColors.textOnDarkSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Never start work before the customer code is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textOnDarkSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: RegExp(r'^\d{4}$').hasMatch(input.text.trim())
                          ? () {
                              final otp = input.text.trim();
                              Navigator.pop(dialogContext, otp);
                            }
                          : null,
                      child: const Text('Verify & start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  input.dispose();
  return result;
}

class _CancelJobButton extends StatefulWidget {
  const _CancelJobButton({required this.job, required this.controller});
  final CustomerBooking job;
  final ProviderController controller;

  @override
  State<_CancelJobButton> createState() => _CancelJobButtonState();
}

class _CancelJobButtonState extends State<_CancelJobButton> {
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error case final message?) ...[
        Text(message, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: AppSpacing.sm),
      ],
      FixButton(
        label: 'Cancel job',
        icon: Icons.cancel_outlined,
        variant: FixButtonVariant.destructive,
        isLoading: loading,
        onPressed: () async {
          final reason = await showCancellationDialog(context);
          if (reason == null) return;
          setState(() {
            loading = true;
            error = null;
          });
          try {
            await widget.controller.cancelJob(widget.job, reason);
          } catch (_) {
            if (mounted) {
              setState(() {
                error =
                    'The job could not be cancelled. Refresh and try again.';
              });
            }
          } finally {
            if (mounted) {
              setState(() {
                loading = false;
              });
            }
          }
        },
      ),
    ],
  );
}
