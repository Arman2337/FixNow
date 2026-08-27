import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/design_system/fix_otp_input_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';

/// Comprehensive interactive job execution cockpit for service technicians (FN-129).
/// Guides the technician through the full real-world lifecycle:
/// - Step 1: Assigned -> Start Journey (begins GPS streaming)
/// - Step 2: En Route -> Verify 4-Digit Customer OTP
/// - Step 3: In Progress -> Before & After Photos -> Complete Service
/// - Step 4: Completed
class ProviderActiveJobCockpitScreen extends StatefulWidget {
  const ProviderActiveJobCockpitScreen({
    required this.job,
    required this.controller,
    this.chatRepository,
    this.callRepository,
    super.key,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final ChatRepository? chatRepository;
  final CallRepository? callRepository;

  @override
  State<ProviderActiveJobCockpitScreen> createState() =>
      _ProviderActiveJobCockpitScreenState();
}

class _ProviderActiveJobCockpitScreenState
    extends State<ProviderActiveJobCockpitScreen> {
  bool _isProcessing = false;
  String? _inlineError;

  CustomerBooking _currentJob() {
    return widget.controller.jobs.firstWhere(
      (j) => j.id == widget.job.id,
      orElse: () => widget.job,
    );
  }

  Future<void> _handleStartJourney(CustomerBooking job) async {
    setState(() {
      _isProcessing = true;
      _inlineError = null;
    });
    try {
      await widget.controller.advanceJob(job);
      await widget.controller.setLocationConsent(job, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started! Location sharing is active.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Could not start trip: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleVerifyOtp(CustomerBooking job) async {
    final otp = await FixOtpInputSheet.show(context);
    if (otp == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _inlineError = null;
    });

    try {
      await widget.controller.verifyOtpAndStartJob(job, otp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP Verified! Service is now In Progress.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError =
              'Incorrect OTP code. Please ask the customer to re-check their screen.';
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCompleteService(CustomerBooking job) async {
    // Check if proof photos exist
    if (!JobProofRepository.instance.hasProof(job.id)) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('Add Job Photo Proof?'),
          content: const Text(
            'Uploading before and after photos increases customer trust and protects against disputes. Do you want to add photos first?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Skip Photos'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx, false);
                await JobProofVerificationDialog.show(context, bookingId: job.id);
              },
              child: const Text('Add Photos'),
            ),
          ],
        ),
      );
      if (shouldContinue != true && !mounted) return;
    }

    setState(() {
      _isProcessing = true;
      _inlineError = null;
    });

    try {
      await widget.controller.advanceJob(job);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job marked as Completed! Great work.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Could not complete job: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openChat(BuildContext context, CustomerBooking job) {
    if (widget.chatRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat is currently offline.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingChatScreen(
          controller: ChatController(
            repository: widget.chatRepository!,
            bookingId: job.id,
            realtimeClient: widget.controller.realtime,
          ),
        ),
      ),
    );
  }

  void _openCall(BuildContext context, CustomerBooking job) {
    if (widget.callRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('In-app calling is connecting...')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingCallScreen(
          controller: CallController(
            bookingId: job.id,
            repository: widget.callRepository!,
            realtimeClient: widget.controller.realtime,
          ),
        ),
      ),
    );
  }

  void _openMaps(CustomerBooking job) {
    final lat = job.locationLatitude;
    final lng = job.locationLongitude;
    final text = lat != null && lng != null
        ? 'Navigating to lat: ${lat.toStringAsFixed(4)}, lng: ${lng.toStringAsFixed(4)}'
        : 'Navigating to customer location';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: AppColors.accentGold,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final job = _currentJob();
        final shortId = job.id.replaceAll('-', '').substring(0, 8).toUpperCase();

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundPrimary,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Execution Cockpit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'ID #$shortId',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Emergency SOS',
                icon: const Icon(Icons.shield_outlined, color: AppColors.emergency),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safety assistance team alerted.')),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              // 1. Progress Stepper
              _buildProgressStepper(job.status),
              const SizedBox(height: AppSpacing.lg),

              if (_inlineError != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 2. Customer & Job Summary Card
              _buildCustomerJobCard(context, job),
              const SizedBox(height: AppSpacing.lg),

              // 3. Status-Specific Lifecycle Action Card
              _buildLifecycleActionCard(context, job),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressStepper(String status) {
    final steps = ['ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS', 'COMPLETED'];
    final labels = ['Assigned', 'On the Way', 'Working', 'Done'];
    final currentIndex = steps.indexOf(status);

    return FixCard(
      tone: FixCardTone.elevated,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JOB PROGRESS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              FixStatusChip(
                label: status.replaceAll('_', ' '),
                icon: Icons.route_rounded,
                tone: status == 'COMPLETED'
                    ? FixStatusTone.success
                    : (status == 'IN_PROGRESS'
                        ? FixStatusTone.warning
                        : FixStatusTone.info),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(steps.length, (index) {
              final isPassed = index <= currentIndex;
              final isCurrent = index == currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed
                                  ? (isCurrent
                                      ? AppColors.accentGold
                                      : AppColors.primary)
                                  : AppColors.backgroundSecondary,
                              border: Border.all(
                                color: isPassed
                                    ? AppColors.borderGold
                                    : AppColors.borderDefault,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isPassed && !isCurrent ? Icons.check : Icons.circle,
                              size: isPassed && !isCurrent ? 16 : 8,
                              color: isPassed ? Colors.black : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isPassed ? AppColors.cream : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < steps.length - 1)
                      Container(
                        width: 24,
                        height: 2,
                        color: index < currentIndex
                            ? AppColors.primary
                            : AppColors.borderDefault,
                        margin: const EdgeInsets.only(bottom: 18),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerJobCard(BuildContext context, CustomerBooking job) {
    final lat = job.locationLatitude;
    final lng = job.locationLongitude;
    final locationText = lat != null && lng != null
        ? 'Customer Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'
        : 'Customer Location (Address on file)';

    return FixCard(
      tone: FixCardTone.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.serviceCategoryId.replaceAll('_', ' ').toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.description,
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.cream,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.borderDefault),
          const SizedBox(height: AppSpacing.sm),

          // Location details
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.emergency, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(fontSize: 13, color: AppColors.cream),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Action row: Navigate, Chat, Call
          Row(
            children: [
              Expanded(
                child: FixButton(
                  label: 'Navigate',
                  icon: Icons.directions_rounded,
                  variant: FixButtonVariant.secondary,
                  onPressed: () => _openMaps(job),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Chat with customer',
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () => _openChat(context, job),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filledTonal(
                tooltip: 'Call customer',
                icon: const Icon(Icons.phone_rounded),
                onPressed: () => _openCall(context, job),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleActionCard(BuildContext context, CustomerBooking job) {
    if (job.status == 'ASSIGNED') {
      return FixCard(
        tone: FixCardTone.elevated,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_car_rounded, color: AppColors.accentGold),
                SizedBox(width: 8),
                Text(
                  'Ready to Depart?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Starting your journey notifies the customer and activates live GPS sharing so they can track your arrival.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              key: const Key('cockpit_start_journey_button'),
              label: 'Start Journey (On My Way)',
              icon: Icons.route_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handleStartJourney(job),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Job'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final reason = await showCancellationDialog(context);
                if (reason != null && context.mounted) {
                  await widget.controller.cancelJob(job, reason);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      );
    }

    if (job.status == 'EN_ROUTE') {
      final sharing = widget.controller.locationSharing[job.id] == true;

      return FixCard(
        tone: FixCardTone.elevated,
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderColor: AppColors.borderGold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AppColors.accentGold),
                    SizedBox(width: 8),
                    Text(
                      'Arrived at Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sharing ? 'GPS Live' : 'GPS Idle',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Once you meet the customer, ask them for the 4-digit Service Start Code shown on their phone.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              key: const Key('cockpit_verify_otp_button'),
              label: 'Enter Customer Start PIN',
              icon: Icons.pin_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handleVerifyOtp(job),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: Icon(
                sharing ? Icons.location_off_rounded : Icons.my_location_rounded,
                size: 16,
              ),
              label: Text(sharing ? 'Pause GPS Broadcast' : 'Resume GPS Broadcast'),
              onPressed: () => widget.controller.setLocationConsent(job, !sharing),
            ),
          ],
        ),
      );
    }

    if (job.status == 'IN_PROGRESS') {
      final hasProof = JobProofRepository.instance.hasProof(job.id);
      final proof = JobProofRepository.instance.getProof(job.id);

      return FixCard(
        tone: FixCardTone.elevated,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.build_circle_rounded, color: AppColors.accentGold),
                SizedBox(width: 8),
                Text(
                  'Service in Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Perform the requested repair. Ensure you take clear before and after photos as proof of quality service.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),

            if (proof != null) ...[
              JobProofViewerCard(proof: proof),
              const SizedBox(height: AppSpacing.md),
            ],

            FixButton(
              label: hasProof ? 'Update Verification Photos' : 'Add Before & After Photos',
              icon: Icons.camera_alt_rounded,
              variant: FixButtonVariant.secondary,
              onPressed: () => JobProofVerificationDialog.show(
                context,
                bookingId: job.id,
                initialProof: proof,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FixButton(
              key: const Key('cockpit_complete_service_button'),
              label: 'Complete Service',
              icon: Icons.task_alt_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handleCompleteService(job),
            ),
          ],
        ),
      );
    }

    // COMPLETED
    return FixCard(
      tone: FixCardTone.elevated,
      borderColor: AppColors.success,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Job Completed',
            style: AppTypography.heading3.copyWith(color: AppColors.cream),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'The invoice has been generated for the customer and your earnings have been recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          FixButton(
            label: 'Back to Workspace',
            variant: FixButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
