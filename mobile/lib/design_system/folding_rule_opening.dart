import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The launcher mark at rest. Adjacent FixNow text supplies its semantics.
class FoldingRuleTile extends StatelessWidget {
  const FoldingRuleTile({super.key, required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: CustomPaint(
      size: Size.square(size),
      painter: const _RulePainter(topAngle: 0, middleAngle: 0),
    ),
  );
}

/// A skippable cold-start overlay. The destination can initialize behind it.
class FoldingRuleOpening extends StatefulWidget {
  const FoldingRuleOpening({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<FoldingRuleOpening> createState() => _FoldingRuleOpeningState();
}

class _FoldingRuleOpeningState extends State<FoldingRuleOpening>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2400);
  static const _reducedDuration = Duration(milliseconds: 120);

  late final _controller =
      AnimationController(
        vsync: this,
        // Reduced motion has its own short, stationary fade below.
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  bool? _reducedMotion;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_finished || _reducedMotion == reduced) return;
    // Once reduced motion has taken over, finish the short fade even if the
    // setting changes again during its remaining frames.
    if (_reducedMotion == true) return;
    _reducedMotion = reduced;
    _controller.duration = reduced ? _reducedDuration : _duration;
    _controller.forward(from: 0);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _controller.stop();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final reduced = _reducedMotion!;
              final time = _controller.value * _duration.inMilliseconds;
              final fade = reduced
                  ? _controller.value
                  : _progress(time, 2100, 300);
              final word = reduced ? 1.0 : _progress(time, 1450, 340);
              return Opacity(
                opacity: 1 - fade,
                child: Material(
                  color: AppColors.primary,
                  child: SafeArea(
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              final size = math.min(
                                240.0,
                                math.min(
                                  bounds.maxWidth * .58,
                                  bounds.maxHeight * .47,
                                ),
                              );
                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Opacity(
                                        opacity: reduced
                                            ? 1
                                            : _progress(time, 0, 300),
                                        child: CustomPaint(
                                          size: Size.square(size),
                                          painter: _RulePainter(
                                            topAngle: reduced
                                                ? 0
                                                : _hingeAngle(time, 300, 650),
                                            middleAngle: reduced
                                                ? 0
                                                : _hingeAngle(time, 950, 500),
                                          ),
                                        ),
                                      ),
                                      Opacity(
                                        opacity: word,
                                        child: Transform.translate(
                                          offset: Offset(
                                            0,
                                            AppSpacing.xs * (1 - word),
                                          ),
                                          child: Text(
                                            'FixNow',
                                            style: FixNowTypography.displayLarge
                                                .copyWith(
                                                  fontSize: size * .25,
                                                  height: 1.1,
                                                  letterSpacing: -size * .01875,
                                                  color: AppColors.onPrimary,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.onPrimary,
                                minimumSize: const Size(64, 48),
                              ),
                              onPressed: _finish,
                              child: const Text(
                                'Skip',
                                semanticsLabel: 'Skip FixNow opening',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _progress(double time, double start, double duration) =>
    Curves.easeOut.transform(((time - start) / duration).clamp(0.0, 1.0));

double _hingeAngle(double time, double start, double duration) {
  const settleAngle = -2.0;
  const curve = Cubic(.32, 0, .22, 1);
  final progress = ((time - start) / duration).clamp(0.0, 1.0);
  final degrees = progress < .84
      ? 90 + (settleAngle - 90) * curve.transform(progress / .84)
      : settleAngle * (1 - curve.transform((progress - .84) / (1.0 - .84)));
  return degrees * math.pi / 180;
}

/// Geometry in the 180-unit viewBox of the approved folding-rule icon.
class _RulePainter extends CustomPainter {
  const _RulePainter({required this.topAngle, required this.middleAngle});

  final double topAngle;
  final double middleAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    canvas.translate(90, 90);
    canvas.rotate(math.pi / 30);
    canvas.translate(-90, -90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 27, 23, 131),
        const Radius.circular(10),
      ),
      paint..color = AppColors.primaryFixed,
    );
    paint
      ..color = AppColors.primary
      ..strokeWidth = 2;
    const stemTicks = [63.0, 72.0, 108.0, 117.0, 126.0, 135.0];
    for (var index = 0; index < stemTicks.length; index++) {
      final y = stemTicks[index];
      canvas.drawLine(Offset(47, y), Offset(index.isEven ? 54 : 51, y), paint);
    }
    _arm(
      canvas,
      const Offset(58, 38),
      topAngle,
      const Rect.fromLTWH(47, 27, 98, 23),
      AppColors.onPrimary,
      82,
      6,
      8,
    );
    _arm(
      canvas,
      const Offset(58, 88),
      middleAngle,
      const Rect.fromLTWH(47, 78, 76, 21),
      const Color(0xFFC7FFE5),
      83,
      4,
      7,
    );
    canvas.drawCircle(const Offset(58, 38), 4, paint);
    canvas.drawCircle(const Offset(58, 88), 4, paint);
    canvas.restore();
  }

  void _arm(
    Canvas canvas,
    Offset pin,
    double angle,
    Rect bounds,
    Color face,
    double firstTick,
    int count,
    double longTick,
  ) {
    canvas.save();
    canvas.translate(pin.dx, pin.dy);
    canvas.rotate(angle);
    canvas.translate(-pin.dx, -pin.dy);
    final paint = Paint()..color = face;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(10)),
      paint,
    );
    paint
      ..color = const Color(0xFF44806D)
      ..strokeWidth = 2;
    for (var index = 0; index < count; index++) {
      final x = firstTick + 9 * index;
      final length = index.isEven ? longTick : longTick - 3;
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.top + length),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) =>
      topAngle != oldDelegate.topAngle ||
      middleAngle != oldDelegate.middleAngle;
}
