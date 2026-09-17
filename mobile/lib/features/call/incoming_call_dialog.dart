import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_audio_service.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

/// Full-screen or modal incoming call alert for Customer and Provider (FN-133).
class IncomingCallDialog extends StatefulWidget {
  const IncomingCallDialog({
    required this.session,
    required this.repository,
    this.realtimeClient,
    this.callerTitle = 'FixNow Voice Call',
    super.key,
  });

  final CallSession session;
  final CallRepository repository;
  final RealtimeClient? realtimeClient;
  final String callerTitle;

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required CallSession session,
    required CallRepository repository,
    RealtimeClient? realtimeClient,
    String? callerTitle,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    HapticFeedback.heavyImpact();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IncomingCallDialog(
          session: session,
          repository: repository,
          realtimeClient: realtimeClient,
          callerTitle:
              callerTitle ??
              (session.callerRole == 'PROVIDER'
                  ? 'Verified Service Technician'
                  : 'Customer Call'),
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final CallController _controller;
  StreamSubscription<RealtimeProjection>? _realtimeSub;
  bool _reduce = false;

  /// Set when decline/accept took ownership of the controller; the dialog
  /// must then not dispose it (accept hands it to the call screen).
  bool _resolvedCall = false;

  @override
  void initState() {
    super.initState();
    // Play system incoming call ringtone + vibration
    CallAudioService.playIncomingRingtone();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _controller = CallController(
      bookingId: widget.session.bookingId,
      repository: widget.repository,
      realtimeClient: widget.realtimeClient,
      initialSession: widget.session,
      autoStart: false,
      initialSpeakerOn: true,
    );

    // If caller cancels before we answer, auto-dismiss
    _realtimeSub = widget.realtimeClient?.projections.listen((p) {
      final type = p.data['type']?.toString();
      final data = p.data['data'];
      if (data is Map && data['bookingId'] == widget.session.bookingId) {
        if (type == 'call.ended.v1' || type == 'call.rejected.v1') {
          CallAudioService.stop();
          if (mounted) Navigator.of(context).maybePop();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited-widget reads belong here, not initState. Ambient loops are
    // stopped (not merely hidden) under reduce motion.
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduce) {
      _pulseController.stop();
      _ringController.stop();
      _pulseController.value = 0.5;
    } else {
      if (_pulseController.status != AnimationStatus.forward) {
        _pulseController.repeat(reverse: true);
      }
      if (_ringController.status != AnimationStatus.forward) {
        _ringController.repeat();
      }
    }
  }

  @override
  void dispose() {
    if (_controller.currentSession?.status != CallStatus.connected) {
      CallAudioService.stop();
      // Nobody took ownership (auto-dismiss or a failed answer): stop the
      // controller's reconciliation poll so it doesn't leak.
      if (!_resolvedCall) _controller.dispose();
    }
    _pulseController.dispose();
    _ringController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    final nav = Navigator.of(context);
    await CallAudioService.stop();
    await _controller.answer();
    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingCallScreen(
          controller: _controller,
          providerName: widget.callerTitle,
          serviceTitle: 'In-App Secure Audio',
        ),
      ),
    );
  }

  Future<void> _handleDecline() async {
    final nav = Navigator.of(context);
    _resolvedCall = true;
    await CallAudioService.stop();
    nav.pop();
    await _controller.decline();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderGold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentGoldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGold),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: AppColors.accentGold,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'SECURE IN-APP CALL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Ringing avatar: outward wave rings + the breathing pulse.
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_reduce)
                    _RingPulse(controller: _ringController, phase: 0),
                  if (!_reduce)
                    _RingPulse(controller: _ringController, phase: 1 / 3),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                      CurvedAnimation(
                        parent: _pulseController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              widget.callerTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Incoming Voice Call...',
              style: TextStyle(
                color: AppColors.textOnSurfaceSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Buttons (Decline / Accept)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _handleDecline,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Decline',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Accept Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _handleAccept,
                      borderRadius: BorderRadius.circular(32),
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _reduce ? 0.5 : _pulseController.value;
                          return Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.live.withValues(
                                    alpha: 0.20 + 0.20 * pulse,
                                  ),
                                  blurRadius: 12 + 10 * pulse,
                                  spreadRadius: 2 + 4 * pulse,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Accept',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One outward-traveling wave ring. Two instances share the controller with
/// different phases for the stagger; transform + opacity only.
class _RingPulse extends StatelessWidget {
  const _RingPulse({required this.controller, required this.phase});

  final AnimationController controller;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - phase) % 1.0;
        return Transform.scale(
          scale: 0.75 + (1.45 - 0.75) * t,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.live.withValues(alpha: (1 - t) * 0.55),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
