import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';

/// ETA progress ring for the tracking screen. The backend only exposes
/// remaining minutes (no journey total), so the sweep replays on each ETA
/// update — honest update progress, not a fake journey fraction. Null
/// [minutes] renders an empty ring with a dash, matching the screen's
/// "Unavailable" copy. Static ring + plain text under reduce motion.
class EtaProgressRing extends StatelessWidget {
  const EtaProgressRing({
    required this.minutes,
    this.size = 44,
    this.color = AppColors.live,
    this.track = AppColors.liveSoft,
    this.textColor = AppColors.cream,
    super.key,
  });

  final int? minutes;
  final double size;
  final Color color;
  final Color track;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final labelStyle = TextStyle(
      color: textColor,
      fontSize: size * 0.3,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget ring;
    if (minutes == null) {
      ring = CustomPaint(
        size: Size.square(size),
        painter: _EtaRingPainter(sweep: 0, color: color, track: track),
      );
    } else if (reduceMotion) {
      ring = CustomPaint(
        size: Size.square(size),
        painter: _EtaRingPainter(
          sweep: math.pi * 2,
          color: color,
          track: track,
        ),
      );
    } else {
      ring = TweenAnimationBuilder<double>(
        key: ValueKey(minutes),
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.emphasis,
        curve: AppMotion.enterCurve,
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _EtaRingPainter(
            sweep: math.pi * 2 * t,
            color: color,
            track: track,
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
          if (minutes == null)
            Text(
              '—',
              style: labelStyle.copyWith(
                color: textColor.withValues(alpha: 0.5),
              ),
            )
          else if (reduceMotion)
            Text('${minutes!}', style: labelStyle)
          else
            FixCountUp(value: minutes!, style: labelStyle),
        ],
      ),
    );
  }
}

class _EtaRingPainter extends CustomPainter {
  _EtaRingPainter({
    required this.sweep,
    required this.color,
    required this.track,
  });

  final double sweep;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.1;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_EtaRingPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
