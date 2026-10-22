import 'package:flutter/material.dart';

/// 3D Holographic Tilt Card with dynamic light reflection sheen.
///
/// Reacts to pointer hover (desktop/web) and touch pan (mobile) by applying
/// a perspective 3D matrix rotation and a moving specular radial highlight.
/// Gracefully returns to level on exit and renders static flat under reduce motion.
class Fix3DTiltCard extends StatefulWidget {
  const Fix3DTiltCard({
    required this.child,
    this.maxRotationDegrees = 14.0,
    this.borderRadius = 16.0,
    this.sheenColor = const Color(0x33FFFFFF),
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final double maxRotationDegrees;
  final double borderRadius;
  final Color sheenColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  State<Fix3DTiltCard> createState() => _Fix3DTiltCardState();
}

class _Fix3DTiltCardState extends State<Fix3DTiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resetController;
  late Animation<double> _resetAnimX;
  late Animation<double> _resetAnimY;

  double _rotX = 0.0;
  double _rotY = 0.0;
  Offset _pointerPos = const Offset(0.5, 0.5); // Normalized 0..1

  @override
  void initState() {
    super.initState();
    _resetController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          setState(() {
            _rotX = _resetAnimX.value;
            _rotY = _resetAnimY.value;
          });
        });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPointerMove(Offset localPos, Size size) {
    _resetController.stop();
    final normX = (localPos.dx / size.width).clamp(0.0, 1.0);
    final normY = (localPos.dy / size.height).clamp(0.0, 1.0);

    final maxRad = widget.maxRotationDegrees * (3.14159 / 180.0);
    setState(() {
      _rotY = ((normX - 0.5) * 2.0) * maxRad;
      _rotX = -((normY - 0.5) * 2.0) * maxRad;
      _pointerPos = Offset(normX, normY);
    });
  }

  void _onPointerExit() {
    _resetAnimX = Tween<double>(begin: _rotX, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetAnimY = Tween<double>(begin: _rotY, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 180.0;
        final size = Size(width, height);

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // Perspective factor
          ..rotateX(_rotX)
          ..rotateY(_rotY);

        return MouseRegion(
          onHover: (e) => _onPointerMove(e.localPosition, size),
          onExit: (_) => _onPointerExit(),
          child: GestureDetector(
            onTap: widget.onTap,
            onPanUpdate: (e) => _onPointerMove(e.localPosition, size),
            onPanEnd: (_) => _onPointerExit(),
            onPanCancel: _onPointerExit,
            child: Transform(
              alignment: FractionalOffset.center,
              transform: transform,
              child: Stack(
                children: [
                  widget.child,
                  // Dynamic specular radial sheen
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: widget.borderColor != null
                                ? Border.all(color: widget.borderColor!)
                                : null,
                            borderRadius: BorderRadius.circular(
                              widget.borderRadius,
                            ),
                            gradient: RadialGradient(
                              center: Alignment(
                                (_pointerPos.dx * 2.0) - 1.0,
                                (_pointerPos.dy * 2.0) - 1.0,
                              ),
                              radius: 0.85,
                              colors: [widget.sheenColor, Colors.transparent],
                              stops: const [0.0, 1.0],
                            ),
                          ),
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
    );
  }
}
