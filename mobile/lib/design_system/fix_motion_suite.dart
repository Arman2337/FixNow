import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// ============================================================================
/// 1. FixSpringBounce — Tactile Spring Micro-Interaction (FN-132)
///
/// Bounces down smoothly to [scaleDown] (default 0.96) on touch-down and springs
/// back on release with a light haptic click. Degrades to a plain tap detector
/// when `disableAnimations` is enabled.
/// ============================================================================
class FixSpringBounce extends StatefulWidget {
  const FixSpringBounce({
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 120),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  @override
  State<FixSpringBounce> createState() => _FixSpringBounceState();
}

class _FixSpringBounceState extends State<FixSpringBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: widget.scaleDown,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
      HapticFeedback.selectionClick();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context) || widget.onTap == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _controller,
        child: widget.child,
      ),
    );
  }
}

/// ============================================================================
/// 2. StaggeredListReveal — Orchestrated Entry Choreography (FN-132)
///
/// Smoothly slides up and fades in list items based on their [index].
/// Adds a 40ms stagger offset per item for an organic cascade entrance.
/// ============================================================================
class StaggeredListReveal extends StatefulWidget {
  const StaggeredListReveal({
    required this.index,
    required this.child,
    this.staggerDelayMs = 40,
    this.slideDistance = 0.12,
    this.duration = const Duration(milliseconds: 320),
    super.key,
  });

  final int index;
  final Widget child;
  final int staggerDelayMs;
  final double slideDistance;
  final Duration duration;

  @override
  State<StaggeredListReveal> createState() => _StaggeredListRevealState();
}

class _StaggeredListRevealState extends State<StaggeredListReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideDistance),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    final delayMs = widget.index * widget.staggerDelayMs;
    if (delayMs <= 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// ============================================================================
/// 3. FixRollingTicker — Numeric Odometer & Price Counter (FN-132)
///
/// Counts up smoothly to [targetValue] over [duration] using tabular numerals
/// and ease-out curve, creating an authentic luxury fintech feel.
/// ============================================================================
class FixRollingTicker extends StatefulWidget {
  const FixRollingTicker({
    required this.targetValue,
    this.currencySymbol = '₹',
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.showDecimals = false,
    super.key,
  });

  final double targetValue;
  final String currencySymbol;
  final TextStyle? style;
  final Duration duration;
  final bool showDecimals;

  @override
  State<FixRollingTicker> createState() => _FixRollingTickerState();
}

class _FixRollingTickerState extends State<FixRollingTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _prevValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FixRollingTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _prevValue = oldWidget.targetValue;
      _animation = Tween<double>(begin: _prevValue, end: widget.targetValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.cream,
    )).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (_reduceMotion(context)) {
      final formatted = widget.showDecimals
          ? widget.targetValue.toStringAsFixed(2)
          : widget.targetValue.toStringAsFixed(0);
      return Text('${widget.currencySymbol}$formatted', style: effectiveStyle);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentVal = _animation.value;
        final formatted = widget.showDecimals
            ? currentVal.toStringAsFixed(2)
            : currentVal.toStringAsFixed(0);
        return Text(
          '${widget.currencySymbol}$formatted',
          style: effectiveStyle,
        );
      },
    );
  }
}

/// ============================================================================
/// 4. AiPhotoScannerOverlay — AI Vision Diagnostic HUD (FN-132)
///
/// Sweeps an animated emerald/cyan laser bar and targeting brackets over
/// uploaded inspection photos while the AI vision model analyzes the defect.
/// ============================================================================
class AiPhotoScannerOverlay extends StatefulWidget {
  const AiPhotoScannerOverlay({
    required this.child,
    required this.isScanning,
    this.statusText = 'AI Vision Diagnostic Scanning…',
    super.key,
  });

  final Widget child;
  final bool isScanning;
  final String statusText;

  @override
  State<AiPhotoScannerOverlay> createState() => _AiPhotoScannerOverlayState();
}

class _AiPhotoScannerOverlayState extends State<AiPhotoScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isScanning) {
      _sweepController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AiPhotoScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_sweepController.isAnimating) {
      _sweepController.repeat(reverse: true);
    } else if (!widget.isScanning && _sweepController.isAnimating) {
      _sweepController.stop();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isScanning) {
      return widget.child;
    }

    final reduce = _reduceMotion(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,

          // Dark tech scrim overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          // Cyber Corner Brackets
          Positioned.fill(
            child: CustomPaint(
              painter: _HudCornerPainter(
                color: AppColors.info,
              ),
            ),
          ),

          // Sweeping Laser Scan Line
          if (!reduce)
            AnimatedBuilder(
              animation: _sweepController,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, (_sweepController.value * 2) - 1),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.info.withValues(alpha: 0.0),
                          AppColors.info,
                          AppColors.success,
                          AppColors.info,
                          AppColors.info.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.info.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Status Badge Pill
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.statusText,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}

class _HudCornerPainter extends CustomPainter {
  _HudCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const len = 16.0;

    // Top-left
    canvas.drawLine(const Offset(8, 8), const Offset(8 + len, 8), paint);
    canvas.drawLine(const Offset(8, 8), const Offset(8, 8 + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8 - len, 8), paint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8, 8 + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(8, size.height - 8), Offset(8 + len, size.height - 8), paint);
    canvas.drawLine(Offset(8, size.height - 8), Offset(8, size.height - 8 - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8 - len, size.height - 8), paint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8, size.height - 8 - len), paint);
  }

  @override
  bool shouldRepaint(_HudCornerPainter oldDelegate) => oldDelegate.color != color;
}
