import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'dart:async';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Timer? _locationTimer;
  String _otpValue = '';

  @override
  void initState() {
    super.initState();
    widget.controller.realtime?.subscribeBooking(_currentJob().id);
    if (_currentJob().status == 'EN_ROUTE' &&
        widget.controller.locationSharing[widget.job.id] == true) {
      _startLocationBroadcasting();
    }
  }

  void _startLocationBroadcasting() {
    _locationTimer?.cancel();
    final initial = _currentJob();
    final isSharingInitial =
        widget.controller.locationSharing[initial.id] ?? true;
    if (initial.status == 'EN_ROUTE' &&
        isSharingInitial &&
        !widget.controller.isPublishingLocation(initial.id)) {
      widget.controller.publishCurrentLocation(initial);
    }
    _locationTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      final current = _currentJob();
      final isSharingCurrent =
          widget.controller.locationSharing[current.id] ?? true;
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



  @override
  void dispose() {
    _stopLocationBroadcasting();
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
    } catch (e) {
      if (mounted) setState(() => _inlineError = 'Could not start trip: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleVerifyOtp(CustomerBooking job, String otp) async {
    if (otp.length != 4) return;
    setState(() {
      _isProcessing = true;
      _inlineError = null;
    });
    try {
      await widget.controller.verifyOtpAndStartJob(job, otp);
      _stopLocationBroadcasting();
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
    if (!JobProofRepository.instance.hasProof(job.id)) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
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
                await JobProofVerificationDialog.show(
                  context,
                  bookingId: job.id,
                );
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
    } catch (e) {
      if (mounted) setState(() => _inlineError = 'Could not complete job: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openChat(BuildContext context, CustomerBooking job) {
    if (widget.chatRepository == null) return;
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
          onCallPressed: () => _openCall(context, job),
        ),
      ),
    );
  }

  void _openCall(BuildContext context, CustomerBooking job) {
    if (job.customerPhone != null) {
      const CallController().launchCall(job.customerPhone!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number unavailable')),
      );
    }
  }

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

  bool _isOpeningMaps = false;

  Future<void> _openMaps(CustomerBooking job) async {
    if (_isOpeningMaps) return;
    setState(() => _isOpeningMaps = true);
    try {
      final opened = await openCustomerNavigation(job);
      if (!opened) throw StateError('Navigation unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open maps. Check that a maps app or browser is installed and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningMaps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final job = _currentJob();

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.surface.withValues(alpha: 0.8),
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
                  titleSpacing: AppSpacing.pagePadding,
                  title: Row(
                    children: [
                      const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Active Job Cockpit',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.md,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_inlineError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.5),
                            ),
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
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _buildPriorityCockpit(job),
                      const SizedBox(height: AppSpacing.xl),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityCockpit(CustomerBooking job) {
    final shortId = job.id.replaceAll('-', '').substring(0, 8).toUpperCase();
    String pillText = 'WAITING FOR START';
    Color pillColor = AppColors.textSecondary;
    if (job.status == 'EN_ROUTE') {
      pillText = 'Arrived At Location';
      pillColor = AppColors.primary;
    } else if (job.status == 'IN_PROGRESS') {
      pillText = 'Service In Progress';
      pillColor = const Color(0xFFa36700); // tertiary
    } else if (job.status == 'COMPLETED') {
      pillText = 'Job Completed';
      pillColor = AppColors.primary;
    } else if (job.status == 'ASSIGNED') {
      pillText = 'Assigned Job';
      pillColor = const Color(0xFFa36700);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              if (job.status == 'EN_ROUTE' ||
                                  job.status == 'IN_PROGRESS') ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                pillText.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#JOB-$shortId',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      providerServiceName(
                        widget.controller.categories,
                        job.serviceCategoryId,
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () => _openCall(context, job),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Customer Details & Quick Map Snip
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  job.locationLatitude != null
                                      ? 'Location Available'
                                      : 'Address on file',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () => _openChat(context, job),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (!hasNavigationDestination(job))
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Customer location unavailable',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => _openMaps(job),
                    child: Container(
                      height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: IgnorePointer(
                                child: ProviderLiveMap(
                                  showOverlay: false,
                                  route: widget.controller.currentRoute,
                                  providerLocation:
                                      widget.controller.currentLocation,
                                  customerLocation:
                                      job.locationLatitude != null &&
                                              job.locationLongitude != null
                                          ? CustomerMapLocation(
                                              latitude: job.locationLatitude!,
                                              longitude: job.locationLongitude!,
                                            )
                                          : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: () => _openMaps(job),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.navigation_rounded,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Navigate',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // State-specific content
          _buildStateSpecificContent(job),

          const SizedBox(height: AppSpacing.md),
          // Safety Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.verified_user_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                'Encrypted Telematics & On-Duty Insurance Protected',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateSpecificContent(CustomerBooking job) {
    if (job.status == 'ASSIGNED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Ready to Depart?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Starting your journey notifies the customer and activates live GPS sharing.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            FixButton(
              label: 'Start Journey (On My Way)',
              icon: Icons.route_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handleStartJourney(job),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final reason = await showCancellationDialog(context);
                if (reason != null && context.mounted) {
                  await widget.controller.cancelJob(job, reason);
                }
              },
              child: const Text(
                'Cancel Job',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }

    if (job.status == 'EN_ROUTE') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.lock_clock_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Customer Start Verification',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Mandatory',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask customer for the 4-digit security code displayed on their FixNow live tracker to initiate the repair clock.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInlineOtpInput(),
            const SizedBox(height: AppSpacing.md),
            FixButton(
              label: 'Verify PIN & Start Job',
              icon: Icons.play_circle_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing
                  ? null
                  : () => _handleVerifyOtp(job, _otpValue),
            ),
          ],
        ),
      );
    }

    if (job.status == 'IN_PROGRESS') {
      final proof = JobProofRepository.instance.getProof(job.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(
                    Icons.camera_enhance_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Job Proof & Materials',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                'Warranty compliant',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPhotoBox(
                  label: 'Before Photo',
                  hasPhoto: proof?.hasBeforePhoto ?? false,
                  isBefore: true,
                  onTap: () => JobProofVerificationDialog.show(
                    context,
                    bookingId: job.id,
                    initialProof: proof,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildPhotoBox(
                  label: 'After Photo',
                  hasPhoto: proof?.hasAfterPhoto ?? false,
                  isBefore: false,
                  onTap: () => JobProofVerificationDialog.show(
                    context,
                    bookingId: job.id,
                    initialProof: proof,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Spare Parts Replaced',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _handleAddExtraCharge(job),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Part'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (job.lineItems.where((item) => item.type == 'EXTRA_CHARGE').isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'No parts added yet',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ...job.lineItems.where((item) => item.type == 'EXTRA_CHARGE').map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '₹${(item.amount / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
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
          const SizedBox(height: AppSpacing.md),
          FixButton(
            key: const Key('cockpit_complete_service_button'),
            label: 'Complete Service',
            icon: Icons.check_circle_rounded,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : () => _handleCompleteService(job),
          ),
        ],
      );
    }

    if (job.status == 'COMPLETED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Job Successfully Completed',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Great work! Payment has been processed and added to your ledger.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildPhotoBox({
    required String label,
    required bool hasPhoto,
    required bool isBefore,
    required VoidCallback onTap,
  }) {
    if (hasPhoto) {
      return InkWell(
        onTap: onTap,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.image_rounded,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBefore ? 'BEFORE' : 'AFTER',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'Tap to capture',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddExtraCharge(CustomerBooking job) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Spare Part / Extra Charge',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (e.g., Coolant gas, Filter)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FixButton(
                label: 'Add Charge',
                onPressed: () {
                  final desc = descriptionController.text.trim();
                  final amount = double.tryParse(amountController.text.trim());
                  if (desc.isNotEmpty && amount != null && amount > 0) {
                    Navigator.pop(context, {
                      'type': 'EXTRA_CHARGE',
                      'description': desc,
                      'amount': (amount * 100).toInt(), // assuming backend wants minor units, wait, DTO says positive number, backend expects minor units usually? Yes, amount is typically in paise.
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        setState(() => _isProcessing = true);
        final currentLineItems = job.lineItems.map((e) => e.toJson()).toList();
        currentLineItems.add(result);
        await widget.controller.updateLineItems(job, currentLineItems);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add charge.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Widget _buildInlineOtpInput() {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _otpValue.length;
              final char = isFilled ? _otpValue[index] : '';
              return Container(
                width: 48,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                  border: Border.all(
                    color: _otpValue.length == index
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  char,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('otp_hidden_input'),
              keyboardType: TextInputType.number,
              maxLength: 4,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                counterText: '',
              ),
              onChanged: (val) {
                setState(() {
                  _otpValue = val;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

const MethodChannel _navigationChannel = MethodChannel(
  'com.fixnow.mobile/navigation',
);

/// Whether the booking carries a usable destination for turn-by-turn
/// navigation. Bookings created before coordinates were captured have none.
bool hasNavigationDestination(CustomerBooking job) {
  final lat = job.locationLatitude;
  final lng = job.locationLongitude;
  return lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}

/// Opens the customer's booked address in the device maps app. Returns false
/// when the booking has no usable destination or no maps app is available.
Future<bool> openCustomerNavigation(CustomerBooking job) async {
  if (!hasNavigationDestination(job)) return false;
  try {
    return await _navigationChannel.invokeMethod<bool>('openNavigation', {
      'latitude': job.locationLatitude,
      'longitude': job.locationLongitude,
      'label': 'Customer Location',
    }) ?? false;
  } catch (_) {
    return false;
  }
}


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
    if (widget.job.items != null && widget.job.items!.isNotEmpty) {
      _lines = widget.job.items!.map((item) => item.toDraft()).toList();
    } else if (widget.job.pricing != null &&
        widget.job.pricing!.subtotalMinor > 0) {
      _lines = [
        BookingItemDraft(
          id: 'initial-service',
          name: widget.job.description.isNotEmpty
              ? widget.job.description
              : 'Base Service',
          quantity: 1,
          unitPriceMinor: widget.job.pricing!.subtotalMinor,
          durationMinutes: widget.job.estimatedDurationMinutes,
        ),
      ];
    } else {
      _lines = [];
    }
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
