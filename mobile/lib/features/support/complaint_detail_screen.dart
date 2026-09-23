import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

import 'complaint.dart';

class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
    required this.complaint,
  });

  final String complaintId;
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final caseIdShort = complaint.id.split('-').first.toUpperCase();
    final isResolved =
        complaint.status == 'RESOLVED' || complaint.status == 'CLOSED';
    final isInReview = complaint.status == 'IN_REVIEW';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Support Case',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Fair Dispute Guarantee Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: AppColors.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'FixNow Fair Dispute Guarantee',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.primaryFixed,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Escrow funds protected. Verified review or instant fee adjustment.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onPrimaryContainer,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header Case Status Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Support case #$caseIdShort',
                      style: FixNowTypography.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FixStatusChip(
                      label: complaint.status,
                      icon: _getIcon(complaint.status),
                      tone: _getTone(complaint.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _progressMessage(complaint.status),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _progressTitle(complaint.status),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created ${_formatDateTime(complaint.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last updated ${_formatDateTime(complaint.updatedAt)}',
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
          ),
          const SizedBox(height: AppSpacing.md),

          // Resolution Milestones Timeline (Stitch blueprint)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Resolution Milestones',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isResolved
                          ? 'Stage 4 of 4'
                          : (isInReview ? 'Stage 3 of 4' : 'Stage 1 of 4'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTimelineStep(
                  isDone: true,
                  isActive: false,
                  title: 'Complaint Filed',
                  subtitle:
                      'Dispute ticket created from booking record challenge.',
                  date: _formatDateTime(complaint.createdAt),
                ),
                _buildTimelineStep(
                  isDone: true,
                  isActive: false,
                  title: 'Evidence & Details Audited',
                  subtitle:
                      'Support lead cross-matched invoice line items with job logs.',
                  date: _formatDateTime(complaint.createdAt),
                ),
                _buildTimelineStep(
                  isDone: isResolved,
                  isActive: isInReview,
                  title: 'Provider Clarification & Inspection',
                  subtitle: isInReview
                      ? 'Technician response window open. Trust officer reviewing logs.'
                      : 'Technician response completed.',
                  date: isInReview ? 'In Progress' : 'Completed',
                ),
                _buildTimelineStep(
                  isDone: isResolved,
                  isActive: false,
                  isLast: true,
                  title: 'Resolution & Escrow Settlement',
                  subtitle: isResolved
                      ? (complaint.resolutionNotes ??
                            'Dispute resolved successfully.')
                      : 'Final decision or refund issued to source payment.',
                  date: isResolved
                      ? _formatDateTime(complaint.updatedAt)
                      : 'Pending',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Details Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  complaint.category,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  complaint.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          if (complaint.resolutionNotes != null &&
              complaint.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryFixedDim.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Resolution Notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    complaint.resolutionNotes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool isDone,
    required bool isActive,
    required String title,
    required String subtitle,
    required String date,
    bool isLast = false,
  }) {
    Color dotColor = isDone
        ? AppColors.primary
        : (isActive
              ? AppColors.tertiaryContainer
              : AppColors.surfaceContainerHigh);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check,
                          size: 11,
                          color: AppColors.onPrimary,
                        )
                      : (isActive
                            ? const Icon(
                                Icons.sync,
                                size: 11,
                                color: AppColors.onPrimary,
                              )
                            : null),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDone || isActive
                                ? AppColors.textPrimary
                                : AppColors.textDisabled,
                          ),
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
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

  FixStatusTone _getTone(String status) {
    switch (status) {
      case 'OPEN':
      case 'ESCALATED':
        return FixStatusTone.warning;
      case 'IN_REVIEW':
        return FixStatusTone.info;
      case 'RESOLVED':
      case 'CLOSED':
        return FixStatusTone.success;
      default:
        return FixStatusTone.neutral;
    }
  }

  IconData _getIcon(String status) {
    switch (status) {
      case 'OPEN':
      case 'ESCALATED':
        return Icons.report_problem_outlined;
      case 'IN_REVIEW':
        return Icons.schedule_outlined;
      case 'RESOLVED':
      case 'CLOSED':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _progressTitle(String status) {
    switch (status) {
      case 'OPEN':
        return 'Case created';
      case 'IN_REVIEW':
        return 'Support is reviewing your report';
      case 'ESCALATED':
        return 'Escalated to senior operations specialist';
      case 'RESOLVED':
        return 'Resolution complete';
      case 'CLOSED':
        return 'Case closed';
      default:
        return 'Processing support request';
    }
  }

  String _progressMessage(String status) {
    switch (status) {
      case 'OPEN':
        return 'Ticket received by queue';
      case 'IN_REVIEW':
        return 'Under review';
      case 'ESCALATED':
        return 'Priority review in progress';
      case 'RESOLVED':
        return 'Case resolved';
      case 'CLOSED':
        return 'Case closed';
      default:
        return 'Status updated';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year}, $hour:$minute';
  }
}
