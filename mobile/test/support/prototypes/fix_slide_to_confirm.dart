import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Physical Slide to Confirm / Dispatch slider.
///
/// Replaces standard flat buttons on high-stakes operations with a tactile,
/// progressive resistance slider that prevents accidental orders or dispatch calls.
class FixSlideToConfirm extends StatefulWidget {
  const FixSlideToConfirm({
    required this.onConfirmed,
    this.label = 'SLIDE TO DISPATCH ➔',
    this.confirmedLabel = '✓ DISPATCHED',
    this.height = 54.0,
    this.thumbColor = AppColors.primary,
    this.confirmedColor = AppColors.success,
    this.trackColor = AppColors.surfaceElevated,
    super.key,
  });

  final Future<void> Function() onConfirmed;
  final String label;
  final String confirmedLabel;
  final double height;
  final Color thumbColor;
  final Color confirmedColor;
  final Color trackColor;

  @override
  State<FixSlideToConfirm> createState() => _FixSlideToConfirmState();
}

class _FixSlideToConfirmState extends State<FixSlideToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double _dragPosition = 0.0;
  bool _isConfirmed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() {
            _dragPosition = _resetAnimation.value;
          });
        });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isConfirmed || _isLoading) return;
    _resetController.stop();
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
    if (_dragPosition >= maxDrag * 0.5 &&
        _dragPosition - details.delta.dx < maxDrag * 0.5) {
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(double maxDrag) async {
    if (_isConfirmed || _isLoading) return;

    if (_dragPosition >= maxDrag * 0.85) {
      // Confirmed!
      HapticFeedback.heavyImpact();
      setState(() {
        _dragPosition = maxDrag;
        _isConfirmed = true;
        _isLoading = true;
      });

      try {
        await widget.onConfirmed();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Snap back to zero
      _resetAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
      );
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final thumbSize = widget.height - 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - thumbSize - 8.0;

        return Container(
          height: widget.height,
          width: trackWidth,
          decoration: BoxDecoration(
            color: widget.trackColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: _isConfirmed
                  ? widget.confirmedColor.withValues(alpha: 0.6)
                  : AppColors.borderStrong.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Shimmer / label text
              Center(
                child: AnimatedSwitcher(
                  duration: AppMotion.standard,
                  child: Text(
                    _isConfirmed ? widget.confirmedLabel : widget.label,
                    key: ValueKey(_isConfirmed),
                    style: TextStyle(
                      color: _isConfirmed
                          ? widget.confirmedColor
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // Completed fill track
              if (_isConfirmed)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: ColoredBox(
                      color: widget.confirmedColor.withValues(alpha: 0.18),
                    ),
                  ),
                ),

              // Draggable Thumb
              Positioned(
                left:
                    4.0 +
                    (reduceMotion && _isConfirmed ? maxDrag : _dragPosition),
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (_) => _onDragEnd(maxDrag),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: _isConfirmed
                          ? widget.confirmedColor
                          : widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isConfirmed
                                      ? widget.confirmedColor
                                      : widget.thumbColor)
                                  .withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isConfirmed
                                  ? Icons.check_rounded
                                  : Icons.keyboard_double_arrow_right_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
