import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive 5-Star Rating with Elastic Pop & 5-Star Sparkle Burst.
///
/// Tapping stars triggers an elastic rebound animation; rating 5 stars
/// detonates a celebratory gold particle sparkle fireworks explosion.
class FixStarRatingBurst extends StatefulWidget {
  const FixStarRatingBurst({
    this.initialRating = 5,
    this.onRatingChanged,
    this.starSize = 38.0,
    super.key,
  });

  final int initialRating;
  final ValueChanged<int>? onRatingChanged;
  final double starSize;

  @override
  State<FixStarRatingBurst> createState() => _FixStarRatingBurstState();
}

class _FixStarRatingBurstState extends State<FixStarRatingBurst>
    with SingleTickerProviderStateMixin {
  late int _rating;
  late final AnimationController _sparkleController;

  static const _feedbackLabels = [
    'Poor service',
    'Needs improvement',
    'Satisfactory',
    'Very Good Service!',
    'Exceptional 5-Star Service!',
  ];

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(1, 5);
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  void _onStarTapped(int index) {
    setState(() {
      _rating = index;
    });
    HapticFeedback.lightImpact();
    widget.onRatingChanged?.call(index);

    if (index == 5) {
      HapticFeedback.mediumImpact();
      _sparkleController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: !reduceMotion && _sparkleController.isAnimating
              ? _SparklePainter(progress: _sparkleController.value)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _onStarTapped(i),
                  behavior: HitTestBehavior.opaque,
                  child: _StarItem(
                    index: i,
                    isSelected: i <= _rating,
                    starSize: widget.starSize,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _feedbackLabels[_rating - 1],
            key: ValueKey(_rating),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGold,
            ),
          ),
        ),
      ],
    );
  }
}

class _StarItem extends StatelessWidget {
  const _StarItem({
    required this.index,
    required this.isSelected,
    required this.starSize,
    required this.reduceMotion,
  });

  final int index;
  final bool isSelected;
  final double starSize;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accentGold : AppColors.textDisabled;

    if (reduceMotion) {
      return Icon(Icons.star_rounded, color: color, size: starSize);
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(isSelected),
      tween: Tween(begin: isSelected ? 0.75 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.star_rounded,
            color: color,
            size: starSize,
            shadows: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    const count = 16;
    for (var i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi) / count;
      final dist = (30.0 + (i % 3) * 18.0) * progress;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      paint.color = (i % 2 == 0 ? AppColors.accentGold : AppColors.accentGoldHover)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), (4.0 * (1.0 - progress)).clamp(1.0, 4.0), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
