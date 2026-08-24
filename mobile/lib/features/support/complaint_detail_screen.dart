import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Support Case')),
      body: FixPageFrame(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Support case #${complaint.id.split('-').first.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FixStatusChip(
                  label: _statusLabel(complaint.status),
                  icon: _getIcon(complaint.status),
                  tone: _getTone(complaint.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FixCard(
              tone: FixCardTone.elevated,
              semanticLabel: 'Support progress',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progressTitle(complaint.status),
                    style: AppTypography.title.copyWith(
                      color: AppColors.textOnDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _progressMessage(complaint.status),
                    style: AppTypography.body.copyWith(
                      color: AppColors.textOnDarkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Created ${_formatDateTime(complaint.createdAt)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textOnDarkSecondary,
                    ),
                  ),
                  Text(
                    'Last updated ${_formatDateTime(complaint.updatedAt)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textOnDarkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Category',
              style: AppTypography.label.copyWith(
                color: AppColors.textOnDarkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(complaint.category, style: AppTypography.title),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Description',
              style: AppTypography.label.copyWith(
                color: AppColors.textOnDarkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(complaint.description, style: AppTypography.body),
            if (complaint.resolutionNotes != null &&
                complaint.resolutionNotes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Resolution',
                style: AppTypography.label.copyWith(
                  color: AppColors.textOnDarkSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FixCard(
                tone: FixCardTone.standard,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  complaint.resolutionNotes!,
                  style: AppTypography.body,
                ),
              ),
            ],
          ],
        ),
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
        return Icons.warning_amber_rounded;
      case 'IN_REVIEW':
        return Icons.info_outline_rounded;
      case 'RESOLVED':
      case 'CLOSED':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(String status) => switch (status) {
    'OPEN' => 'Received',
    'IN_REVIEW' => 'Under review',
    'ESCALATED' => 'Escalated',
    'RESOLVED' => 'Resolved',
    'CLOSED' => 'Closed',
    _ => 'Update available',
  };

  String _progressTitle(String status) => switch (status) {
    'OPEN' => 'Your report was received',
    'IN_REVIEW' => 'Support is reviewing your report',
    'ESCALATED' => 'Your report needs additional attention',
    'RESOLVED' => 'Support marked this report resolved',
    'CLOSED' => 'This support case is closed',
    _ => 'Support case update',
  };

  String _progressMessage(String status) => switch (status) {
    'OPEN' => 'Our support team will review the details and update this case.',
    'IN_REVIEW' => 'Support is checking the information in your report.',
    'ESCALATED' =>
      'The case was escalated for further attention. We will update it when there is progress.',
    'RESOLVED' => 'Read the resolution note below if one is available.',
    'CLOSED' =>
      'No further action is needed unless support asks you for more information.',
    _ => 'Support will update this case when more information is available.',
  };

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = const [
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
    ][local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year}, $hour:$minute';
  }
}
