import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'complaint.dart';

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

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[localDt.month - 1];
    var hour = localDt.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$month ${localDt.day}, $hour:$minute $ampm';
  }

  void _openProofModal(BuildContext context, String caseId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attach Additional Proof',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload clear photos of serial tags, digital bill meters, or write additional context for your assigned case officer.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo attached!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Upload Photo Proof'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write remarks here...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text('Additional proof submitted to Case Officer.'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _requestCallback(BuildContext context, String caseId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          'Instant callback requested! A Trust & Safety officer will review your case with high priority.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disputes & Cases',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Resolution Hub',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmitComplaintScreen(
                      controller: widget.controller,
                      targetRole: 'PLATFORM',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('New Case'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          switch (widget.controller.listStatus) {
            case ComplaintsListStatus.initial:
            case ComplaintsListStatus.loading:
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            case ComplaintsListStatus.error:
            case ComplaintsListStatus.offline:
              return FixErrorState(
                title: 'Could not load cases',
                message: widget.controller.listError ?? 'An error occurred.',
                onRetry: () => widget.controller.loadComplaints(),
              );
            case ComplaintsListStatus.empty:
            case ComplaintsListStatus.ready:
              final complaints = widget.controller.complaints;
              final activeComplaints = complaints
                  .where((c) => c.status != 'RESOLVED' && c.status != 'CLOSED')
                  .toList();
              final pastComplaints = complaints
                  .where((c) => c.status == 'RESOLVED' || c.status == 'CLOSED')
                  .toList();

              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceContainerLowest,
                onRefresh: () => widget.controller.loadComplaints(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _buildEscrowTrustBanner(),
                    const SizedBox(height: AppSpacing.md),

                    if (complaints.isEmpty) ...[
                      // Empty state with guarantee callout
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: AppSpacing.xl),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'No Active Disputes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'All your bookings are running smoothly under the FixNow 30-Day Guarantee. If you ever need to challenge an invoice or report a defect, file a case below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SubmitComplaintScreen(
                                      controller: widget.controller,
                                      targetRole: 'PLATFORM',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('File a Dispute Case'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Active Highlighted Cases
                      for (final activeCase in activeComplaints) ...[
                        _buildActiveCaseHighlightCard(context, activeCase),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Past Resolved Cases
                      if (pastComplaints.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Past Complaints History',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${pastComplaints.length} Resolved',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final pastCase in pastComplaints) ...[
                          _buildResolvedCaseAccordion(context, pastCase),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ],
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildEscrowTrustBanner() {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.onPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                      size: 15,
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Escrow funds locked. 100% resolution guarantee or instant reversal to original source.',
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
    );
  }

  Widget _buildActiveCaseHighlightCard(BuildContext context, Complaint complaint) {
    final caseShort = complaint.id.length >= 8
        ? complaint.id.substring(0, 8).toUpperCase()
        : complaint.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Meta & Status Pill with Pulse
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#CASE-$caseShort',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                      const SizedBox(width: 6),
                      Text(
                        complaint.bookingId != null
                            ? 'Job #${complaint.bookingId!.substring(0, complaint.bookingId!.length > 8 ? 8 : complaint.bookingId!.length).toUpperCase()}'
                            : 'Target: ${complaint.targetRole}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    complaint.category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      complaint.status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.onTertiaryFixed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Assigned Specialist & SLA Notice Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: const Icon(
                            Icons.support_agent_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trust & Safety Officer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'FixNow Customer Trust Team',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Live Lead',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Case #${complaint.id.length > 8 ? complaint.id.substring(0, 8) : complaint.id} • Under Review',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Interactive Resolution Milestones (Vertical Timeline)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resolution Milestones',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Stage ${complaint.status == 'OPEN' ? 1 : complaint.status == 'IN_PROGRESS' ? 2 : complaint.status == 'PENDING' ? 3 : 4} of 4',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Steps list with vertical line
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              children: [
                _buildMilestoneRow(
                  isDone: true,
                  isActive: complaint.status == 'OPEN',
                  title: 'Complaint Filed',
                  meta: 'Dispute packet created from customer challenge.',
                  time: _formatDateTime(complaint.createdAt),
                ),
                _buildMilestoneRow(
                  isDone: complaint.status != 'OPEN' && complaint.status != 'IN_PROGRESS',
                  isActive: complaint.status == 'IN_PROGRESS',
                  title: 'Evidence & Bill Audited',
                  meta: 'Unit rates matched with technician checklist logs.',
                  time: complaint.status == 'OPEN' ? 'Pending' : _formatDateTime(complaint.updatedAt),
                ),
                _buildMilestoneRow(
                  isDone: complaint.status == 'RESOLVED' || complaint.status == 'CLOSED',
                  isActive: complaint.status == 'PENDING',
                  title: 'Provider Clarification & Audit',
                  meta: 'Technician response window open. IoT logs verified.',
                  time: (complaint.status == 'OPEN' || complaint.status == 'IN_PROGRESS') ? 'Pending' : _formatDateTime(complaint.updatedAt),
                ),
                _buildMilestoneRow(
                  isDone: complaint.status == 'RESOLVED' || complaint.status == 'CLOSED',
                  isActive: complaint.status == 'RESOLVED' || complaint.status == 'CLOSED',
                  isLast: true,
                  title: 'Resolution & Escrow Adjustment / Refund',
                  meta: 'Immediate wallet refund or warranty service re-dispatch.',
                  time: (complaint.status == 'RESOLVED' || complaint.status == 'CLOSED') ? _formatDateTime(complaint.updatedAt) : 'Pending',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Case Particulars Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISPUTED ITEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  complaint.description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Agent Note
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.comment_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Support Agent Note: "${complaint.resolutionNotes ?? 'Case received. Waiting for assigned officer review.'}"',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // User Action Controls (2 buttons)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openProofModal(context, complaint.id),
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('Add Proof'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.outline.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _requestCallback(context, complaint.id),
                  icon: const Icon(Icons.support_agent_rounded, size: 16),
                  label: const Text('Instant Callback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow({
    required bool isDone,
    required bool isActive,
    required String title,
    required String meta,
    required String time,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.primary
                      : (isActive
                          ? AppColors.tertiaryFixed
                          : AppColors.surfaceContainerHigh),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : (isActive ? Icons.sync_rounded : Icons.lock_rounded),
                  size: 12,
                  color: isDone
                      ? AppColors.onPrimary
                      : (isActive ? AppColors.onTertiaryFixed : AppColors.textSecondary),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone
                        ? AppColors.primary
                        : AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                          color: isActive ? AppColors.tertiary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? AppColors.tertiary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    meta,
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

  Widget _buildResolvedCaseAccordion(BuildContext context, Complaint complaint) {
    final caseShort = complaint.id.length >= 8
        ? complaint.id.substring(0, 8).toUpperCase()
        : complaint.id.toUpperCase();

    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          title: Row(
            children: [
              Text(
                '#CASE-$caseShort',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Resolved',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimaryFixed,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            complaint.category,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
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
                    complaint.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resolution Outcome:',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          complaint.resolutionNotes ?? 'Resolved successfully',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
