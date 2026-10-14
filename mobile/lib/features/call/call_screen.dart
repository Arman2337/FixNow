import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_image.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

/// In-app encrypted voice call screen connecting Customer and Service Specialist.
///
/// Strictly isolates roles and reflects the dynamic opposite party:
/// - When opened by Customer: callee is the Provider (shows 'Verified Specialist' + verified badge)
/// - When opened by Provider: callee is the Customer (shows 'Customer' without technician badge)
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.oppositePartyName,
    required this.oppositePartyRole,
    this.phoneNumber,
    this.bookingId,
    this.isProvider = false,
    this.controller,
  });

  /// The display name of the other person on the call.
  final String oppositePartyName;

  /// The dynamic role of the opposite party (e.g. 'Customer' or 'Service Specialist').
  final String oppositePartyRole;

  /// Masked phone number if available.
  final String? phoneNumber;

  /// Active booking ID context.
  final String? bookingId;

  /// Whether the current logged-in user is a provider.
  final bool isProvider;

  /// Optional call controller for VoIP lifecycle.
  final CallController? controller;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  CallStatus _status = CallStatus.connected;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _status == CallStatus.connected) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedDuration {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _endCall() {
    setState(() => _status = CallStatus.ended);
    _timer?.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCustomerOpposite = widget.oppositePartyRole.toLowerCase().contains('customer') || widget.isProvider;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate VoIP canvas
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top privacy & security badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.shield_rounded,
                      color: AppColors.primaryEmerald,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'End-to-End Masked Channel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),

              // Dynamic Avatar with deterministic monogram
              FixAvatar(
                name: widget.oppositePartyName,
                radius: 54,
                verified: !isCustomerOpposite,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Dynamic Opposite Party Name
              Text(
                widget.oppositePartyName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),

              // Dynamic Role Label (Isolated per party)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCustomerOpposite
                      ? Colors.blue.withValues(alpha: 0.15)
                      : AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.oppositePartyRole.toUpperCase(),
                  style: TextStyle(
                    color: isCustomerOpposite
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF6EE7B7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Call status / duration
              Text(
                _status == CallStatus.connected
                    ? _formattedDuration
                    : 'Call ${_status.name}...',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              if (widget.bookingId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Booking #${widget.bookingId!.length > 8 ? widget.bookingId!.substring(0, 8) : widget.bookingId}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // Action buttons bar: Mute, Speaker, Keypad
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  _CallActionButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onTap: _toggleSpeaker,
                  ),
                  _CallActionButton(
                    icon: Icons.dialpad_rounded,
                    label: 'Keypad',
                    isActive: false,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('In-call DTMF keypad')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // End Call button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66EF4444),
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
              const SizedBox(height: AppSpacing.lg),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black87 : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
