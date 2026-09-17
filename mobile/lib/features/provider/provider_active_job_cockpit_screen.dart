import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
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
  State<ProviderActiveJobCockpitScreen> createState() => _ProviderActiveJobCockpitScreenState();
}

class _ProviderActiveJobCockpitScreenState extends State<ProviderActiveJobCockpitScreen> {
  bool _isProcessing = false;
  String? _inlineError;
  StreamSubscription<RealtimeProjection>? _callSub;
  Timer? _locationTimer;
  String _otpValue = '';

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
          _inlineError = 'Incorrect OTP code. Please ask the customer to re-check their screen.';
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
          callRepository: widget.callRepository,
          onCallPressed: () => _openCall(context, job),
        ),
      ),
    );
  }

  void _openCall(BuildContext context, CustomerBooking job) {
    if (widget.callRepository == null) return;
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

  static const MethodChannel _navChannel = MethodChannel('com.fixnow.mobile/navigation');

  Future<void> _openMaps(CustomerBooking job) async {
    final lat = job.locationLatitude ?? 23.0225;
    final lng = job.locationLongitude ?? 72.5714;
    try {
      await _navChannel.invokeMethod('openNavigation', {
        'latitude': lat,
        'longitude': lng,
        'label': 'Customer Location #${job.id.substring(0, 8)}',
      });
    } catch (_) {}
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
                        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.0), BlendMode.dst),
                      ),
                    ),
                  ),
                  elevation: 0,
                  titleSpacing: AppSpacing.pagePadding,
                  title: Row(
                    children: [
                      const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 24),
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
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                            ],
                          ),
                          const Text(
                            'Active Job Cockpit',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_inlineError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              if (job.status == 'EN_ROUTE' || job.status == 'IN_PROGRESS') ...[
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
                      providerServiceName(widget.controller.categories, job.serviceCategoryId),
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
                  child: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
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
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
),
                            ),
                            Text(
                              job.locationLatitude != null ? 'Location Available' : 'Address on file',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                          onPressed: () => _openChat(context, job),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                                  customerLocation: job.locationLatitude != null && job.locationLongitude != null
                                      ? CustomerMapLocation(latitude: job.locationLatitude!, longitude: job.locationLongitude!)
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.navigation_rounded, color: AppColors.primary, size: 14),
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
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 4),
              Text(
                'Encrypted Telematics & On-Duty Insurance Protected',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
),
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
                Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 20),
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
),
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
              child: const Text('Cancel Job', style: TextStyle(color: AppColors.danger)),
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
                    Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInlineOtpInput(),
            const SizedBox(height: AppSpacing.md),
            FixButton(
              label: 'Verify PIN & Start Job',
              icon: Icons.play_circle_rounded,
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handleVerifyOtp(job, _otpValue),
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
                  Icon(Icons.camera_enhance_rounded, color: AppColors.textSecondary, size: 18),
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
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
),
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
                  onTap: () => JobProofVerificationDialog.show(context, bookingId: job.id, initialProof: proof),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildPhotoBox(
                  label: 'After Photo',
                  hasPhoto: proof?.hasAfterPhoto ?? false,
                  isBefore: false,
                  onTap: () => JobProofVerificationDialog.show(context, bookingId: job.id, initialProof: proof),
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
                      onPressed: () {},
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
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'No parts added yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FixButton(
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
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
            SizedBox(height: 8),
            Text(
              'Job Successfully Completed',
              style: TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _buildPhotoBox({required String label, required bool hasPhoto, required bool isBefore, required VoidCallback onTap}) {
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
                child: Center(child: Icon(Icons.image_rounded, color: AppColors.textSecondary, size: 32)),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        isBefore ? 'BEFORE' : 'AFTER',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
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
              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                  ],
                  border: Border.all(
                    color: _otpValue.length == index ? AppColors.primary : Colors.transparent,
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
