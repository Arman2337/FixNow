import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SOS Long-Press Charge Vortex Button.
///
/// Prevents false panic alarms by requiring a deliberate 1.5-second hold.
/// Animates a rotating circular charge vortex ring and expanding red pulse halo.
/// Cancels cleanly upon premature touch-up.
class FixSosVortexButton extends StatefulWidget {
  const FixSosVortexButton({
    required this.onTriggered,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.size = 88.0,
    super.key,
  });

  final VoidCallback onTriggered;
  final Duration holdDuration;
  final double size;

  @override
  State<FixSosVortexButton> createState() => _FixSosVortexButtonState();
}

class _FixSosVortexButtonState extends State<FixSosVortexButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onTriggered();
          _onHoldEnd();
        }
      });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.mediumImpact();
    _holdController.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_isHolding) {
      setState(() => _isHolding = false);
      _holdController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      label: 'Emergency SOS. Press and hold to trigger safety dispatch.',
      child: Listener(
        onPointerDown: (_) => _onHoldStart(),
        onPointerUp: (_) => _onHoldEnd(),
        onPointerCancel: (_) => _onHoldEnd(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: widget.size + 24.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating charging vortex ring
              if (_isHolding && !reduceMotion)
                AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.square(widget.size + 18.0),
                      painter: _VortexRingPainter(progress: _holdController.value),
                    );
                  },
                ),

              // Expanding pulse glow when holding
              if (_isHolding && !reduceMotion)
                AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, _) {
                    return Container(
                      width: widget.size + (_holdController.value * 16.0),
                      height: widget.size + (_holdController.value * 16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergency.withValues(
                          alpha: (0.35 * (1.0 - _holdController.value)).clamp(0.0, 0.35),
                        ),
                      ),
                    );
                  },
                ),

              // Core button medallion
              AnimatedScale(
                scale: _isHolding ? 0.94 : 1.0,
                duration: AppMotion.fast,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emergency.withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        _isHolding ? 'HOLDING...' : 'HOLD 1.5s',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
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
      ),
    );
  }
}

class _VortexRingPainter extends CustomPainter {
  _VortexRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = AppColors.emergency.withValues(alpha: 0.2),
    );

    // Active rotating charge arc
    final sweep = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_VortexRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
