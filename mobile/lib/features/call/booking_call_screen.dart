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
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: AppColors.secondarySlate,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),

              // Top Privacy Shield Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: AppColors.primaryFixed,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Masked In-App Audio • Numbers Protected',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Main Active Call Arena
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.85),
                        const Color(0xFF0F172A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Live Timer Pill / Status Ticker
                      Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status == CallStatus.connected
                                    ? AppColors.primaryFixed
                                    : AppColors.accentGold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _statusLabel(status),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            if (status == CallStatus.connected) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'Active',
                                style: TextStyle(
                                  color: AppColors.primaryFixedDim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center Avatar with Radiating Pulsing Wave Rings
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final isSpeaking = controller.isRemoteSpeaking;
                          final scale =
                              (!disableMotion &&
                                  (status == CallStatus.ringing ||
                                      status == CallStatus.connected))
                              ? (isSpeaking
                                    ? 1.04 + (_pulseController.value * 0.04)
                                    : 1.0 + (_pulseController.value * 0.04))
                              : 1.0;

                          return Transform.scale(
                            scale: scale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!disableMotion &&
                                    (status == CallStatus.ringing ||
                                        status == CallStatus.connected)) ...[
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryFixed.withValues(
                                        alpha:
                                            0.12 *
                                            (1.0 - _pulseController.value),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryFixedDim
                                          .withValues(
                                            alpha: 0.2 * _pulseController.value,
                                          ),
                                    ),
                                  ),
                                ],
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primaryFixed,
                                        Colors.white,
                                        AppColors.primaryFixedDim,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: AppColors.secondarySlate,
                                    child: Text(
                                      widget.providerName.isNotEmpty
                                          ? widget.providerName[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: AppColors.primaryFixed,
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 18,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryFixed,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified_rounded,
                                      color: AppColors.onPrimaryFixed,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Technician Identifier & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.providerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixedDim.withValues(
                                alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: AppColors.accentGold,
                                  size: 13,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '4.9',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      const Text(
                        'FixNow Verified Specialist',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(),

                      // Audio Waveform Visualizer
                      if (status == CallStatus.connected) ...[
                        FixAudioWaveform(
                          isSpeaking: controller.isRemoteSpeaking,
                          height: 26,
                          activeColor: AppColors.primaryFixed,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.isRemoteSpeaking
                              ? 'Speaking with customer'
                              : 'Direct Audio Stream Connected',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ] else if (controller.isReconnecting) ...[
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Job Reference Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Active Job Context',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${widget.controller.bookingId.length > 8 ? widget.controller.bookingId.substring(0, 8) : widget.controller.bookingId}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.serviceTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

              const SizedBox(height: AppSpacing.sm),

              // Circular Call Actions Grid
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
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
                          onPressed:
                              status == CallStatus.connected ||
                                  status == CallStatus.ringing
                              ? controller.toggleMute
                              : null,
                        ),

                        // Speakerphone Button
                        _CallActionButton(
                          icon: controller.isSpeakerOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_down_rounded,
                          label: 'Speaker',
                          isActive: controller.isSpeakerOn,
                          onPressed:
                              status == CallStatus.connected ||
                                  status == CallStatus.ringing
                              ? controller.toggleSpeaker
                              : null,
                        ),

                        // Keypad / Dialpad
                        _CallActionButton(
                          icon: Icons.dialpad_rounded,
                          label: 'Keypad',
                          isActive: false,
                          onPressed: () {},
                        ),

                        // Live Chat
                        _CallActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          isActive: false,
                          onPressed: () {
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Large Crimson End Call CTA
                    InkWell(
                      onTap: () {
                        controller.hangup();
                        Navigator.of(context).maybePop();
                      },
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x55FF4D4F),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xs),
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
              color: isActive ? AppColors.primary : AppColors.surfaceElevated,
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
