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
                Text(
                  'Case ID: ${complaint.id.split('-').first}',
                  style: AppTypography.label,
                ),
                FixStatusChip(
                  label: complaint.status,
                  icon: _getIcon(complaint.status),
                  tone: _getTone(complaint.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Category',
              style: AppTypography.label.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              complaint.category,
              style: AppTypography.title,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Description',
              style: AppTypography.label.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              complaint.description,
              style: AppTypography.body,
            ),
            if (complaint.resolutionNotes != null &&
                complaint.resolutionNotes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Resolution',
                style: AppTypography.label.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
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
}
