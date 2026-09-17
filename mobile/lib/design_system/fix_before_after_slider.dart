import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';

/// An interactive before-and-after photo comparison slider widget.
/// Allows users to swipe left and right to visually inspect repair work.
class FixBeforeAfterSlider extends StatefulWidget {
  const FixBeforeAfterSlider({
    this.beforeBytes,
    this.afterBytes,
    this.beforeUrl,
    this.afterUrl,
    this.beforeWidget,
    this.afterWidget,
    this.height = 240,
    this.initialPosition = 0.5,
    super.key,
  });

  final Uint8List? beforeBytes;
  final Uint8List? afterBytes;
  final String? beforeUrl;
  final String? afterUrl;
  final Widget? beforeWidget;
  final Widget? afterWidget;
  final double height;
  final double initialPosition;

  @override
  State<FixBeforeAfterSlider> createState() => _FixBeforeAfterSliderState();
}

class _FixBeforeAfterSliderState extends State<FixBeforeAfterSlider> {
  late double _sliderPosition;

  @override
  void initState() {
    super.initState();
    _sliderPosition = widget.initialPosition.clamp(0.05, 0.95);
  }

  void _handleDrag(DragUpdateDetails details, double totalWidth) {
    if (totalWidth <= 0) return;
    setState(() {
      _sliderPosition = (_sliderPosition + details.delta.dx / totalWidth).clamp(
        0.02,
        0.98,
      );
    });
  }

  Widget _buildPhotoContent({
    Uint8List? bytes,
    String? url,
    Widget? customWidget,
    required String fallbackLabel,
    required IconData fallbackIcon,
  }) {
    if (customWidget != null) return customWidget;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) =>
            _buildPlaceholder(fallbackLabel, fallbackIcon),
      );
    }
    return _buildPlaceholder(fallbackLabel, fallbackIcon);
  }

  Widget _buildPlaceholder(String label, IconData icon) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 36),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: AppRadius.cardBorder,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final dividerX = width * _sliderPosition;

            return Stack(
              children: [
                // 1. After photo (full width underneath)
                Positioned.fill(
                  child: _buildPhotoContent(
                    bytes: widget.afterBytes,
                    url: widget.afterUrl,
                    customWidget: widget.afterWidget,
                    fallbackLabel: 'After Service Photo',
                    fallbackIcon: Icons.check_circle_outline_rounded,
                  ),
                ),

                // 2. Before photo (clipped from left to dividerX)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: dividerX,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: width,
                      maxWidth: width,
                      minHeight: widget.height,
                      maxHeight: widget.height,
                      child: _buildPhotoContent(
                        bytes: widget.beforeBytes,
                        url: widget.beforeUrl,
                        customWidget: widget.beforeWidget,
                        fallbackLabel: 'Before Service Photo',
                        fallbackIcon: Icons.history_rounded,
                      ),
                    ),
                  ),
                ),

                // 3. Before Badge (Top Left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'BEFORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                // 4. After Badge (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'AFTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                // 5. Vertical Divider Line
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: dividerX - 1.5,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Center Drag Handle
                Positioned(
                  top: (widget.height / 2) - 18,
                  left: dividerX - 18,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) =>
                        _handleDrag(details, width),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceElevated,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.compare_arrows_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // 7. Full-surface drag overlay
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) =>
                        _handleDrag(details, width),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
