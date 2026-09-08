import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:flutter/material.dart';

/// 3D Spatial Geolocation Radar Beacon.
///
/// Combines a 3D-angled elliptical radar grid with spinning sweep rings
/// and a kinetic hovering beacon pin with dynamic ground shadow casting.
class Fix3DSpatialBeacon extends StatefulWidget {
  const Fix3DSpatialBeacon({
    this.label = 'Matching in your area',
    this.sublabel = 'Searching within 5 km radius…',
    this.primaryColor = AppColors.primary,
    this.accentColor = AppColors.focus,
    this.size = 180.0,
    this.progress,
    super.key,
  });

  final String label;
  final String sublabel;
  final Color primaryColor;
  final Color accentColor;
  final double size;
  final double? progress;

  @override
  State<Fix3DSpatialBeacon> createState() => _Fix3DSpatialBeaconState();
}

class _Fix3DSpatialBeaconState extends State<Fix3DSpatialBeacon>
    with SingleTickerProviderStateMixin {
  AnimationController? _floatController;
  late final Animation<double> _floatAnim;
  late final Animation<double> _shadowScaleAnim;

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) {
      _floatController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
      _floatAnim = Tween<double>(begin: -10.0, end: 6.0).animate(
        CurvedAnimation(parent: _floatController!, curve: Curves.easeInOutSine),
      );
      _shadowScaleAnim = Tween<double>(begin: 0.75, end: 1.15).animate(
        CurvedAnimation(parent: _floatController!, curve: Curves.easeInOutSine),
      );
    } else {
      _floatAnim = const AlwaysStoppedAnimation(0.0);
      _shadowScaleAnim = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size * 0.85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 3D Angled Ground Radar Grid
              Transform(
                alignment: FractionalOffset.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateX(1.15),
                child: reduceMotion
                    ? Container(
                        width: widget.size * 0.9,
                        height: widget.size * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.accentColor.withValues(alpha: 0.4), width: 2),
                        ),
                      )
                    : Transform.rotate(
                        angle: (widget.progress ?? 0.0) * 2 * math.pi,
                        child: CustomPaint(
                          size: Size(widget.size * 0.9, widget.size * 0.9),
                          painter: _SpatialRadarGridPainter(
                            color: widget.accentColor,
                          ),
                        ),
                      ),
              ),

              // Dynamic Blur Shadow on Ground
              Positioned(
                bottom: 24,
                child: reduceMotion
                    ? Container(
                        width: 32,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _shadowScaleAnim,
                        builder: (context, _) {
                          return Transform.scale(
                            scaleX: _shadowScaleAnim.value,
                            scaleY: _shadowScaleAnim.value * 0.6,
                            child: Container(
                              width: 38,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Hovering 3D Pin Beacon
              reduceMotion
                  ? _buildPin()
                  : AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: _buildPin(),
                        );
                      },
                    ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.sublabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPin() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(0),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accentColor,
            widget.primaryColor,
            const Color(0xFF1E3A8A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      transform: Matrix4.rotationZ(-math.pi / 4),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white70,
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpatialRadarGridPainter extends CustomPainter {
  const _SpatialRadarGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, outerPaint);
    canvas.drawCircle(center, radius * 0.65, innerPaint);
    canvas.drawCircle(center, radius * 0.35, innerPaint);

    // Crosshairs
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
