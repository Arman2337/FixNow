import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

/// Animated VoIP Audio Waveform Visualizer.
///
/// Visually communicates native PCM 16kHz audio frame streaming and
/// silence gating (< 200 amplitude threshold). When the remote or local party
/// speaks, the frequency bars dance in emerald/cobalt. During silence or mute,
/// the bars collapse to calm minimal ticks, saving bandwidth & cognitive load.
class FixAudioWaveform extends StatefulWidget {
  const FixAudioWaveform({
    this.isSpeaking = true,
    this.barCount = 7,
    this.height = 36.0,
    this.activeColor = AppColors.live,
    this.idleColor = AppColors.borderStrong,
    super.key,
  });

  final bool isSpeaking;
  final int barCount;
  final double height;
  final Color activeColor;
  final Color idleColor;

  @override
  State<FixAudioWaveform> createState() => _FixAudioWaveformState();
}

class _FixAudioWaveformState extends State<FixAudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isSpeaking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FixAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.borderStrong.withValues(alpha: 0.25),
        ),
      ),
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.barCount; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _buildBar(i, reduceMotion),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBar(int index, bool reduceMotion) {
    final maxHeight = widget.height - 12;
    double barHeight;

    if (!widget.isSpeaking || reduceMotion) {
      barHeight = 4.0;
    } else {
      // Deterministic pseudo-random frequency wave based on controller tick and bar index
      final phase = (index * 0.45) + (_controller.value * 2 * math.pi);
      final wave = (math.sin(phase) + 1.0) / 2.0; // 0.0 to 1.0
      barHeight = 4.0 + (wave * (maxHeight - 4.0));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 4,
      height: barHeight,
      decoration: BoxDecoration(
        color: widget.isSpeaking
            ? widget.activeColor
            : widget.idleColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
