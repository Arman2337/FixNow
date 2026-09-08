import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_audio_waveform.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

class BookingCallScreen extends StatefulWidget {
  const BookingCallScreen({
    super.key,
    required this.controller,
    this.providerName = 'Verified Professional',
    this.serviceTitle = 'Active Service',
  });

  final CallController controller;
  final String providerName;
  final String serviceTitle;

  @override
  State<BookingCallScreen> createState() => _BookingCallScreenState();
}

class _BookingCallScreenState extends State<BookingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _popTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _pulseController.dispose();
    _popTimer?.cancel();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      if (widget.controller.status == CallStatus.ended ||
          widget.controller.status == CallStatus.rejected) {
        _popTimer?.cancel();
        _popTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        });
      }
    }
  }

  String _statusLabel(CallStatus status) {
    switch (status) {
      case CallStatus.initiated:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connected:
        return widget.controller.formattedDuration;
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.rejected:
        return 'Call declined';
      case CallStatus.missed:
        return 'No answer';
      case CallStatus.failed:
        return widget.controller.errorMessage ?? 'Call failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final status = controller.status;
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Top Privacy Shield Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.borderStrong.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.shield_rounded,
                      color: AppColors.focus,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Masked In-App Audio • Numbers Protected',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              // Avatar with acoustic radar pulsation & live speaking ripples
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final isSpeaking = controller.isRemoteSpeaking;
                  final scale = (!disableMotion &&
                          (status == CallStatus.ringing ||
                              status == CallStatus.connected))
                      ? (isSpeaking
                          ? 1.05 + (_pulseController.value * 0.05)
                          : 1.0 + (_pulseController.value * 0.06))
                      : 1.0;
                  final pulseAlpha = (!disableMotion &&
                          (status == CallStatus.ringing ||
                              status == CallStatus.connected))
                      ? 0.3 * (1.0 - _pulseController.value)
                      : 0.0;

                  return Transform.scale(
                    scale: scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSpeaking && !disableMotion) ...[
                          Container(
                            width: 172,
                            height: 172,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 152,
                            height: 152,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success.withValues(alpha: 0.16),
                            ),
                          ),
                        ] else if (pulseAlpha > 0)
                          Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: pulseAlpha,
                              ),
                            ),
                          ),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceElevated,
                            boxShadow: isSpeaking
                                ? [
                                    BoxShadow(
                                      color: AppColors.success.withValues(alpha: 0.45),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : null,
                            border: Border.all(
                              color: isSpeaking
                                  ? AppColors.success
                                  : (status == CallStatus.connected
                                      ? AppColors.primary
                                      : AppColors.borderStrong),
                              width: isSpeaking ? 4 : 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: AppColors.textPrimary,
                              size: 64,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Live Speaking or Reconnecting Feedback Badge
              if (controller.isReconnecting)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.accentGold),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentGold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Reconnecting audio...',
                        style: TextStyle(
                          color: AppColors.accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (controller.isRemoteSpeaking)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: AppColors.success,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Speaking...',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.sm),

              // Recipient Name & Verification
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.providerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.focus,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.serviceTitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 12),

              // Status Ticker
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == CallStatus.connected
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: status == CallStatus.connected
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              if (status == CallStatus.connected) ...[
                const SizedBox(height: AppSpacing.sm),
                FixAudioWaveform(
                  isSpeaking: controller.isRemoteSpeaking,
                  height: 32,
                  activeColor: AppColors.success,
                ),
              ],

              const Spacer(),

              // In-Call Action Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Microphone Button
                  _CallActionButton(
                    icon: controller.isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: controller.isMuted ? 'Unmute' : 'Mute',
                    isActive: controller.isMuted,
                    onPressed: status == CallStatus.connected ||
                            status == CallStatus.ringing
                        ? controller.toggleMute
                        : null,
                  ),

                  // End Call Button (Large Red)
                  InkWell(
                    onTap: () {
                      controller.hangup();
                      Navigator.of(context).maybePop();
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x66FF4D4F),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Speakerphone Button
                  _CallActionButton(
                    icon: controller.isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    isActive: controller.isSpeakerOn,
                    onPressed: status == CallStatus.connected ||
                            status == CallStatus.ringing
                        ? controller.toggleSpeaker
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.primary
                  : AppColors.surfaceElevated,
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : AppColors.borderStrong.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.textPrimary,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
