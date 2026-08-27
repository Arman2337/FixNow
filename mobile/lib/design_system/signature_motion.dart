import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// ============================================================================
/// 1. MatchRadarView — post-submit choreography (FN-040 made visible)
///
/// Gate: occasional event covering a real async wait. Purpose: bridging the
/// submit→dispatch gap and showing that real providers are being alerted.
/// Rings are transform+opacity only, ease-out, skippable, and collapse to
/// staged text under reduce-motion.
/// ============================================================================
class MatchRadarView extends StatefulWidget {
  const MatchRadarView({
    required this.onFinished,
    this.categoryName,
    super.key,
  });

  final VoidCallback onFinished;
  final String? categoryName;

  @override
  State<MatchRadarView> createState() => _MatchRadarViewState();
}

class _MatchRadarViewState extends State<MatchRadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  static const _stages = [
    'Sharing your request…',
    'Alerting verified professionals near you…',
    'You will see the moment someone accepts.',
  ];

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 220,
              child: reduce
                  ? const Center(
                      child: Icon(
                        Icons.wifi_tethering_rounded,
                        color: AppColors.primary,
                        size: 56,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        size: const Size.fromHeight(220),
                        painter: _RadarPainter(progress: _controller.value),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedSwitcher(
              duration: AppMotion.container,
              switchInCurve: AppMotion.enterCurve,
              child: Text(
                key: ValueKey(stageText(reduce)),
                stageText(reduce),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (widget.categoryName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.categoryName!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            TextButton(onPressed: _skip, child: const Text('Skip')),
          ],
        ),
      ),
    );
  }

  String stageText(bool reduce) {
    // Deterministic stage progression driven by controller time; identical
    // stages under reduce-motion so copy never depends on motion availability.
    final t = reduce ? 1.0 : _controller.value;
    final index = t < 0.34
        ? 0
        : t < 0.72
        ? 1
        : 2;
    return _stages[index];
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 12;

    // Center pin stays put; three rings launch 700ms apart (skill stagger).
    for (var i = 0; i < 3; i++) {
      final start = i * 0.23;
      if (progress <= start) continue;
      final t = ((progress - start) / 0.5).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - t, 3).toDouble(); // ease-out cubic
      final radius = maxRadius * (0.25 + 0.75 * eased);
      final opacity = (1 - t) * 0.55;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.primary.withValues(alpha: opacity),
      );
    }

    canvas.drawCircle(
      center,
      10,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      center,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.primary.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ============================================================================
/// 2. FlipOtpDigits — the handshake moment
///
/// Gate: rare, high-stakes reveal — the delight budget applies. Staggered
/// 60ms per digit, ease-out flips, haptic tick as each digit lands,
/// opacity-only under reduce-motion. Replaces the static row inside
/// FixOtpDisplay with an identical resting layout.
/// ============================================================================
class FlipOtpDigits extends StatefulWidget {
  const FlipOtpDigits({required this.otp, super.key});

  final String otp;

  @override
  State<FlipOtpDigits> createState() => _FlipOtpDigitsState();
}

class _FlipOtpDigitsState extends State<FlipOtpDigits>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _hapticsFired = 0;

  int get digitCount => widget.otp.length.clamp(1, 8);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.container + Duration(milliseconds: 60 * digitCount),
    )..forward();
    _controller.addListener(() {
      // One light tick as each digit lands (skill: feedback, not decoration).
      final landed =
          (_controller.value * digitCount).floor().clamp(0, digitCount);
      while (_hapticsFired < landed) {
        HapticFeedback.lightImpact();
        _hapticsFired += 1;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    if (reduce) {
      _hapticsFired = digitCount;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < digitCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DigitBox(digit: widget.otp[i]),
            ),
        ],
      );
    }

    final totalMs = AppMotion.container.inMilliseconds + 60 * digitCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < digitCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final startMs = i * 60;
                final t = Interval(
                  startMs / totalMs,
                  ((startMs + AppMotion.container.inMilliseconds) / totalMs)
                      .clamp(0.0, 1.0),
                  curve: AppMotion.enterCurve,
                ).transform(_controller.value);
                // Flip up from -90deg with opacity; transform+opacity only.
                final angle = (1 - t) * math.pi / 2;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateX(angle),
                    child: child,
                  ),
                );
              },
              child: _DigitBox(digit: widget.otp[i]),
            ),
          ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit});

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.accentGold, width: 1.5),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          color: AppColors.textOnLightPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// ============================================================================
/// 3. HoldToConfirmButton — deliberate friction done right
///
/// Policy §3 friction IS the feature. Asymmetric timing per the skill: slow
/// linear fill while held (~1.6s), snappy 200ms release if abandoned. Assistive
/// tech gets an instant semantic tap path (NFR-ACC-003): the hold is
/// sighted-user deliberation, never an accessibility wall.
/// ============================================================================
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1600),
    super.key,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    reverseDuration: const Duration(milliseconds: 200),
  );
  var _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_confirmed) {
        _confirmed = true;
        widget.onConfirmed();
        _thump(HapticFeedback.mediumImpact);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _holdStart(LongPressStartDetails details) {
    if (_confirmed) {
        return;
    }
    _controller.forward();
    _thump(HapticFeedback.selectionClick);
  }

  void _holdEnd(LongPressEndDetails details) => _abandon();

  void _abandon() {
    if (!_confirmed && !_controller.isAnimating) return;
    if (!_confirmed) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return Semantics(
      button: true,
      onTap: () {
        // Assistive path: instant confirmation without the hold.
        if (!_confirmed) {
          _confirmed = true;
          widget.onConfirmed();
        }
      },
      label: '${widget.label}. Double-tap to confirm immediately.',
      child: GestureDetector(
        onLongPressStart: reduce ? null : _holdStart,
        onLongPressEnd: reduce ? null : _holdEnd,
        onLongPressCancel: () => _abandon(),
        // Tap fallback for reduced motion users: simple tap confirms.
        onTap: reduce
            ? () {
                if (!_confirmed) {
                  _confirmed = true;
                  widget.onConfirmed();
                }
              }
            : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              foregroundPainter: _RingProgressPainter(
                progress: reduce ? (_confirmed ? 1 : 0) : _controller.value,
                color: AppColors.danger,
              ),
              child: child,
            );
          },
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.14),
              borderRadius: AppRadius.buttonBorder,
              border: Border.all(color: AppColors.danger, width: 1.4),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fire-and-forget haptics: platform-channel failures must never break the
/// interaction they accompany.
void _thump(VoidCallback feedback) {
  try {
    feedback();
  } catch (_) {
    // No haptic capability (tests, web, unsupported devices).
  }
}

class _RingProgressPainter extends CustomPainter {
  const _RingProgressPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = AppRadius.buttonBorder.toRRect(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [color.withValues(alpha: 0.15), color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ============================================================================
/// 4. Status temperature — lifecycle read by color
///
/// Pure state indication. Colors warm toward gold as work progresses and
/// mute on cancellation. Consumed by booking cards with a 340ms
/// ease-in-out transition (AppMotion.container family).
/// ============================================================================
Color statusTemperatureColor(String status) => switch (status) {
      'REQUESTED' => AppColors.primary,
      'ASSIGNED' => AppColors.primary,
      'EN_ROUTE' => AppColors.success,
      'IN_PROGRESS' => AppColors.warning,
      'COMPLETED' => AppColors.rating,
      _ => AppColors.textSecondary,
    };
