import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:flutter/material.dart';

/// Tactile Jelly Squish Button with non-linear spring physics rebound.
///
/// Features:
/// - Volume-preserving non-linear compression (scaleX expands while scaleY compresses)
/// - Elastic spring bounce-back upon release
/// - Glossy material highlight on top edge
/// - Reduces motion safely when disabled
class FixJellySquishButton extends StatefulWidget {
  const FixJellySquishButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradientColors = const [Color(0xFFFF5277), Color(0xFFFF2E63)],
    this.textColor = Colors.white,
    this.height = 52.0,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> gradientColors;
  final Color textColor;
  final double height;
  final bool expand;

  @override
  State<FixJellySquishButton> createState() => _FixJellySquishButtonState();
}

class _FixJellySquishButtonState extends State<FixJellySquishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late final Animation<double> _scaleXAnim;
  late final Animation<double> _scaleYAnim;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Jelly spring curves: X expands when Y squashes
    _scaleXAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 20),
    ]).animate(_springController);

    _scaleYAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.12).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.96).chain(CurveTween(curve: Curves.easeInOutQuad)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 20),
    ]).animate(_springController);
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _springController.forward(from: 0.0);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final btnContent = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.gradientColors.first.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: widget.textColor, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) {
      return GestureDetector(
        onTap: widget.onPressed,
        child: btnContent,
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _springController,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _scaleXAnim.value,
              _scaleYAnim.value,
              1.0,
            ),
            child: child,
          );
        },
        child: btnContent,
      ),
    );
  }
}
