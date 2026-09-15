import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/design_system/fix_otp_input_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'dart:async';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/call/incoming_call_dialog.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  StreamSubscription<RealtimeProjection>? _callSub;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.realtime?.subscribeBooking(_currentJob().id);
    _listenForIncomingCalls();
    if (_currentJob().status == 'EN_ROUTE' &&
        widget.controller.locationSharing[widget.job.id] == true) {
      _startLocationBroadcasting();
    }
  }

  void _startLocationBroadcasting() {
    _locationTimer?.cancel();
    // Immediately publish first location so customer map gets live route without delay
    final initial = _currentJob();
    final isSharingInitial = widget.controller.locationSharing[initial.id] ?? true;
    if (initial.status == 'EN_ROUTE' &&
        isSharingInitial &&
        !widget.controller.isPublishingLocation(initial.id)) {
      widget.controller.publishCurrentLocation(initial);
    }
    _locationTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      final current = _currentJob();
      final isSharingCurrent = widget.controller.locationSharing[current.id] ?? true;
      if (current.status == 'EN_ROUTE' &&
          isSharingCurrent &&
          !widget.controller.isPublishingLocation(current.id)) {
        await widget.controller.publishCurrentLocation(current);
      }
    });
  }

  void _stopLocationBroadcasting() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _listenForIncomingCalls() {
    _callSub = widget.controller.realtime?.projections.listen((p) {
      final type = p.data['type']?.toString();
      final data = p.data['data'];
      if (type == 'call.incoming.v1' && data is Map) {
        final session = CallSession.fromJson(Map<String, Object?>.from(data));
        // Only show incoming call dialog if caller is NOT the provider
        if (session.callerRole != 'PROVIDER' &&
            widget.callRepository != null &&
            mounted) {
          IncomingCallDialog.show(
            context,
            session: session,
            repository: widget.callRepository!,
            realtimeClient: widget.controller.realtime,
            callerTitle: 'Customer Booking #${_currentJob().id.substring(0, 8)}',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _stopLocationBroadcasting();
    _callSub?.cancel();
    super.dispose();
  }

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
      final updated = await widget.controller.advanceJob(job);
      final current = updated ?? _currentJob();
      await widget.controller.setLocationConsent(current, true);
      await widget.controller.publishCurrentLocation(current);
      _startLocationBroadcasting();
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          tone: FixBannerTone.success,
          title: 'Trip started',
          message: 'Location sharing is active.',
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
      _stopLocationBroadcasting();
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          tone: FixBannerTone.success,
          title: 'OTP verified',
          message: 'Service is now in progress.',
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
      // The cockpit rebuilds to the green COMPLETED card — that is the
      // success feedback; no snackbar on top of it.
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Could not complete job: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// On-site adjustment: the provider edits the itemized services once the
  /// real scope of work is visible. The backend recomputes the totals and
  /// the customer sees the revised list on their booking.
  Future<void> _openServiceAdjustment(CustomerBooking job) async {
    final updated = await showModalBottomSheet<CustomerBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServiceAdjustmentSheet(
        job: job,
        controller: widget.controller,
      ),
    );
    if (updated != null && mounted) {
      showFixBanner(
        ScaffoldMessenger.of(context),
        tone: FixBannerTone.success,
        title: 'Services updated',
        message: 'The customer now sees the revised services and total.',
      );
    }
  }

  void _openChat(BuildContext context, CustomerBooking job) {
    if (widget.chatRepository == null) {
      showFixBanner(
        ScaffoldMessenger.of(context),
        tone: FixBannerTone.danger,
        message: 'Chat is currently offline.',
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
            isProvider: true,
          ),
          providerName: 'Customer',
          callRepository: widget.callRepository,
          onCallPressed: () => _openCall(context, job),
        ),
      ),
    );
  }

  void _openCall(BuildContext context, CustomerBooking job) {
    if (widget.callRepository == null) {
      showFixBanner(
        ScaffoldMessenger.of(context),
        message: 'In-app calling is connecting...',
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
            initialSpeakerOn: true,
          ),
        ),
      ),
    );
  }

  static const MethodChannel _navChannel =
      MethodChannel('com.fixnow.mobile/navigation');

  Future<void> _openMaps(CustomerBooking job) async {
    final lat = job.locationLatitude ?? 12.9716;
    final lng = job.locationLongitude ?? 77.5946;

    try {
      await _navChannel.invokeMethod('openNavigation', {
        'latitude': lat,
        'longitude': lng,
        'label': 'Customer Location #${job.id.substring(0, 8)}',
      });
    } on MissingPluginException {
      if (!mounted) return;
      showFixBanner(
        ScaffoldMessenger.of(context),
        message:
            'Navigating to lat: ${lat.toStringAsFixed(4)}, lng: ${lng.toStringAsFixed(4)}',
        actionLabel: 'DISMISS',
      );
    } catch (_) {
      if (!mounted) return;
      showFixBanner(
        ScaffoldMessenger.of(context),
        message:
            'Navigating to lat: ${lat.toStringAsFixed(4)}, lng: ${lng.toStringAsFixed(4)}',
      );
    }
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
                  showFixBanner(
                    ScaffoldMessenger.of(context),
                    message: 'Safety assistance team alerted.',
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
              onPressed: () async {
                final current = _currentJob();
                await widget.controller.setLocationConsent(current, !sharing);
                if (!sharing) {
                  _startLocationBroadcasting();
                } else {
                  _stopLocationBroadcasting();
                }
              },
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
            const SizedBox(height: AppSpacing.md),

            FixButton(
              key: const Key('cockpit_adjust_services_button'),
              label: 'Adjust Services & Price',
              icon: Icons.tune_rounded,
              variant: FixButtonVariant.secondary,
              onPressed: () => _openServiceAdjustment(job),
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

/// Bottom sheet for editing the booking's line items on site. Quantities
/// step down to zero to remove a line; custom work found on site is added
/// by name and price. Totals shown here mirror the backend formula
/// (subtotal + 18% GST).
class _ServiceAdjustmentSheet extends StatefulWidget {
  const _ServiceAdjustmentSheet({required this.job, required this.controller});

  final CustomerBooking job;
  final ProviderController controller;

  @override
  State<_ServiceAdjustmentSheet> createState() =>
      _ServiceAdjustmentSheetState();
}

class _ServiceAdjustmentSheetState extends State<_ServiceAdjustmentSheet> {
  late List<BookingItemDraft> _lines;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines = List<BookingItemDraft>.from(widget.job.items ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _money(int minor) =>
      '₹${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';

  int get _subtotalMinor => _lines.fold(
        0,
        (sum, item) => sum + item.unitPriceMinor * item.quantity,
      );

  void _increment(int index) {
    final line = _lines[index];
    setState(() {
      _lines[index] = BookingItemDraft(
        id: line.id,
        name: line.name,
        quantity: line.quantity + 1,
        unitPriceMinor: line.unitPriceMinor,
        durationMinutes: line.durationMinutes,
      );
    });
  }

  void _decrement(int index) {
    final line = _lines[index];
    setState(() {
      if (line.quantity > 1) {
        _lines[index] = BookingItemDraft(
          id: line.id,
          name: line.name,
          quantity: line.quantity - 1,
          unitPriceMinor: line.unitPriceMinor,
          durationMinutes: line.durationMinutes,
        );
      } else {
        _lines.removeAt(index);
      }
    });
  }

  void _addCustomItem() {
    final name = _nameCtrl.text.trim();
    final rupees = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty || rupees == null || rupees < 0) return;
    setState(() {
      _lines = [
        ..._lines,
        BookingItemDraft(
          id: 'on-site-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          quantity: 1,
          unitPriceMinor: (rupees * 100).round(),
        ),
      ];
    });
    _nameCtrl.clear();
    _priceCtrl.clear();
  }

  Future<void> _submit() async {
    if (_lines.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final updated =
        await widget.controller.updateJobItems(widget.job, _lines);
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _saving = false;
        _error =
            widget.controller.actionError ?? 'Services could not be updated.';
      });
      return;
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adjust Services',
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Text(
                  'Update the work actually done. The customer sees the revised list and total.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),

                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'No services on this booking yet. Add the work you are doing.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                else
                  for (var i = 0; i < _lines.length; i++) ...[
                    _buildLineRow(_lines[i], i),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                const SizedBox(height: AppSpacing.md),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Customer pays (incl. 18% GST)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      _money((_subtotalMinor * 1.18).round()),
                      style: const TextStyle(
                        color: AppColors.focus,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                const Text(
                  'Add work found on site',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _sheetInput('e.g. New tap cartridge'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _sheetInput('₹ price'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InkWell(
                      onTap: _addCustomItem,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),

                FixButton(
                  label: 'Update Booking',
                  icon: Icons.check_rounded,
                  isLoading: _saving,
                  onPressed: _lines.isEmpty ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineRow(BookingItemDraft line, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_money(line.unitPriceMinor)} × ${line.quantity} = '
                  '${_money(line.unitPriceMinor * line.quantity)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _decrement(index),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.remove_rounded, color: Colors.white, size: 18),
            ),
          ),
          InkWell(
            onTap: () => _increment(index),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _sheetInput(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );
}
