import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

import 'complaints_controller.dart';
import 'complaint_detail_screen.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key, required this.controller});
  
  final ComplaintsController controller;

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Cases')),
      body: FixPageFrame(
        child: ListenableBuilder(
          listenable: widget.controller,
        builder: (context, _) {
          switch (widget.controller.listStatus) {
            case ComplaintsListStatus.initial:
            case ComplaintsListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ComplaintsListStatus.error:
            case ComplaintsListStatus.offline:
              return FixErrorState(
                title: 'Could not load cases',
                message: widget.controller.listError ?? 'An error occurred.',
                onRetry: () => widget.controller.loadComplaints(),
                
              );
            case ComplaintsListStatus.empty:
              return const FixEmptyState(
                title: 'No support cases yet',
                message: 'When you file a complaint, it will appear here.',
                icon: Icons.support_agent,
              );
            case ComplaintsListStatus.ready:
              final complaints = widget.controller.complaints;
              return RefreshIndicator(
                onRefresh: () => widget.controller.loadComplaints(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: complaints.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    return FixCard(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ComplaintDetailScreen(
                            complaintId: complaint.id,
                            complaint: complaint,
                          ),
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  complaint.category,
                                  style: AppTypography.title,
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
                              complaint.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Opened: ${_formatDate(complaint.createdAt)}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    ));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
