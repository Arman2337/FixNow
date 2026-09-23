import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/ratings/booking_review_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({
    required this.booking,
    this.onCancel,
    this.onReschedule,
    this.onReportIssue,
    this.reviewRepository,
    this.onBookAgain,
    this.onViewInvoice,
    this.onSubmitClaim,
    super.key,
  });
  final CustomerBooking booking;
  final Future<CustomerBooking> Function(String reason)? onCancel;
  final VoidCallback? onReschedule;
  final VoidCallback? onReportIssue;
  final BookingRepository? reviewRepository;
  final VoidCallback? onBookAgain;
  final VoidCallback? onViewInvoice;
  final VoidCallback? onSubmitClaim;

  @override
  Widget build(BuildContext context) {
    final panel = _statusPanel(booking.statusValue);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface.withValues(alpha: 0.85),
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRect(
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.0),
                    BlendMode.dst,
                  ),
                ),
              ),
            ),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                const Text(
                  'FixNow',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  '/',
                  style: TextStyle(
                    color: AppColors.outlineVariant,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Details',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header Panel
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.statusValue.label,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#${_shortId(booking.id)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: panel.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (const {
                              BookingStatusValue.inProgress,
                              BookingStatusValue.enRoute,
                            }.contains(booking.statusValue)) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: panel.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              panel.title.toUpperCase(),
                              style: TextStyle(
                                color: panel.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Timeline
                _BookingProgress(status: booking.status),
                const SizedBox(height: AppSpacing.md),

                // Assigned Professional
                if (const {
                  BookingStatusValue.assigned,
                  BookingStatusValue.enRoute,
                  BookingStatusValue.inProgress,
                }.contains(booking.statusValue)) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Assigned Professional',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Verified Partner • Vetted',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Scheduled Time
                if (booking.scheduledAt != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Scheduled for: ${_formatScheduledTime(booking.scheduledAt!)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Service Request Block
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Gradient line
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primarySoft,
                              AppColors.primaryFixedDim,
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.build_circle_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  _category(booking.serviceCategoryId),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              booking.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            if (booking.items case final items? when items.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              const Divider(
                                height: 1,
                                color: AppColors.surfaceContainerHigh,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'BOOKED SERVICES',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.quantity == 1
                                              ? item.name
                                              : '\ × ',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _money(item.lineTotalMinor),
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (booking.pricing case final pricing?) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total (incl. GST)',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      pricing.formattedTotal,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(
                              height: 1,
                              color: AppColors.surfaceContainerHigh,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DATE REQUESTED',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _date(booking.createdAt),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'BOOKING ID',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.tag_rounded,
                                          color: AppColors.primary,
                                          size: 14,
                                        ),
                                        Text(
                                          _shortId(booking.id),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (JobProofRepository.instance.getProof(booking.id)
                    case final proof?) ...[
                  const SizedBox(height: AppSpacing.md),
                  JobProofViewerCard(proof: proof),
                ],

                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Identity, ETA, and live tracking map appear only when the assigned provider shares location.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                // Actions Block
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (booking.statusValue.isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FixNow 30-Day Guarantee',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Active until ${DateFormat('MMM d, yyyy').format(booking.createdAt.add(const Duration(days: 30)))}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: onSubmitClaim,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Claim', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (booking.statusValue.isCompleted &&
                        onBookAgain != null) ...[
                      FixButton(
                        label: 'Book Again',
                        icon: Icons.refresh_rounded,
                        onPressed: onBookAgain,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (onViewInvoice != null && booking.statusValue.isCompleted) ...[
                      FixButton(
                        label: 'View / Pay Invoice',
                        icon: Icons.receipt_long_rounded,
                        onPressed: onViewInvoice,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (onReschedule != null &&
                        const {
                          BookingStatusValue.requested,
                          BookingStatusValue.assigned,
                        }.contains(booking.statusValue)) ...[
                      FixButton(
                        label: 'Reschedule Date / Time',
                        icon: Icons.event_repeat_rounded,
                        variant: FixButtonVariant.secondary,
                        onPressed: onReschedule,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (onReportIssue != null) ...[
                      FixButton(
                        label: 'Dispute / Report Issue',
                        icon: Icons.contact_support_outlined,
                        variant: FixButtonVariant.secondary,
                        onPressed: onReportIssue,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (booking.statusValue.isCompleted &&
                        reviewRepository != null) ...[
                      BookingReviewPanel(
                        booking: booking,
                        repository: reviewRepository!,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (onCancel != null &&
                        const {
                          BookingStatusValue.requested,
                          BookingStatusValue.assigned,
                        }.contains(booking.statusValue)) ...[
                      _CancelButton(booking: booking, onCancel: onCancel!),
                    ],
                  ],
                ),
                // Bottom padding
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatScheduledTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} at $hour:$minute $ampm';
  }

  static ({IconData icon, Color color, String title}) _statusPanel(
    BookingStatusValue value,
  ) => switch (value) {
    BookingStatusValue.requested => (
      icon: Icons.radar_rounded,
      color: AppColors.primary,
      title: 'Requested',
    ),
    BookingStatusValue.assigned ||
    BookingStatusValue.enRoute ||
    BookingStatusValue.inProgress => (
      icon: Icons.route_rounded,
      color: AppColors.primary,
      title: 'Active',
    ),
    BookingStatusValue.completed => (
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
      title: 'Completed',
    ),
    BookingStatusValue.cancelled => (
      icon: Icons.cancel_rounded,
      color: AppColors.danger,
      title: 'Cancelled',
    ),
    BookingStatusValue.unknown => (
      icon: Icons.help_outline_rounded,
      color: AppColors.warning,
      title: 'Status unavailable',
    ),
  };
  static String _category(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  static String _shortId(String value) {
    final compact = value.replaceAll('-', '');
    final short = compact.length <= 8 ? compact : compact.substring(0, 8);
    return short.toUpperCase();
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  static String _money(int minor) =>
      '₹${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';
}

class _BookingProgress extends StatelessWidget {
  const _BookingProgress({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusValue = BookingStatusValue.parse(status);
    final current = switch (statusValue) {
      BookingStatusValue.requested => 0,
      BookingStatusValue.assigned => 1,
      BookingStatusValue.enRoute => 2,
      BookingStatusValue.inProgress => 3,
      BookingStatusValue.completed => 4,
      _ => -1,
    };
    const stages = [
      ('Requested', 'Matching eligible professionals'),
      ('Assigned', 'A professional confirmed the booking'),
      ('En Route', 'Your professional is travelling to you'),
      ('Work started', 'The service is in progress'),
      ('Completed', 'The job has been marked complete'),
    ];

    if (statusValue.isCancelled) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.danger),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Booking was cancelled.',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (statusValue == BookingStatusValue.unknown) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.warning),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Booking status is unavailable. Refresh to get the latest update.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Status',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var index = 0; index < stages.length; index++)
            _ProgressRow(
              title: stages[index].$1,
              description: stages[index].$2,
              isComplete: current >= index,
              isCurrent: current == index,
              isLast: index == stages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.title,
    required this.description,
    required this.isComplete,
    required this.isCurrent,
    required this.isLast,
  });

  final String title;
  final String description;
  final bool isComplete;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? AppColors.primary
                      : (isComplete
                            ? AppColors.primarySoft
                            : AppColors.surfaceContainerHighest),
                  border: isCurrent
                      ? Border.all(color: AppColors.primaryFixedDim, width: 2)
                      : null,
                ),
                child: Center(
                  child: Icon(
                    isComplete && !isCurrent
                        ? Icons.check_rounded
                        : Icons.circle,
                    size: 14,
                    color: isCurrent
                        ? Colors.white
                        : (isComplete
                              ? AppColors.primary
                              : AppColors.outlineVariant),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isComplete && !isCurrent
                        ? AppColors.primarySoft
                        : AppColors.surfaceContainerHigh,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.primary
                        : (isComplete
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _CancelButton extends StatefulWidget {
  const _CancelButton({required this.booking, required this.onCancel});
  final CustomerBooking booking;
  final Future<CustomerBooking> Function(String reason) onCancel;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error case final message?) ...[
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      FixButton(
        label: 'Cancel Booking',
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
            await widget.onCancel(reason);
            if (context.mounted) Navigator.of(context).pop();
          } catch (_) {
            if (mounted) {
              setState(() {
                loading = false;
                error =
                    'The booking could not be cancelled. Refresh and try again.';
              });
            }
          }
        },
      ),
    ],
  );
}
