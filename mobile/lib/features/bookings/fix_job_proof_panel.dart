import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_before_after_slider.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_controller.dart';
import 'package:flutter/material.dart';

/// FN-143. The customer's view of what their pro photographed on site.
///
/// The design rule this exists to honour: never show a half-empty frame that
/// reads as "the work was never recorded". Every state that is not the full
/// before/after pair says what is missing and why, in words. A slider showing
/// one real photo and one blank half would be a lie about the evidence.
class FixJobProofPanel extends StatefulWidget {
  const FixJobProofPanel({
    required this.controller,
    required this.bookingId,
    super.key,
  });

  final JobProofController controller;
  final String bookingId;

  @override
  State<FixJobProofPanel> createState() => _FixJobProofPanelState();
}

class _FixJobProofPanelState extends State<FixJobProofPanel> {
  @override
  void initState() {
    super.initState();
    // Loads once per booking. Guarded on the id so a rebuild — and every
    // rebuild the parent does on a realtime projection — does not re-request
    // the photographs.
    if (widget.controller.bookingId != widget.bookingId) {
      widget.controller.load(widget.bookingId);
    }
  }

  @override
  void didUpdateWidget(covariant FixJobProofPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId) {
      widget.controller.load(widget.bookingId);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _buildPanel(context),
  );

  Widget _buildPanel(BuildContext context) {
    final controller = widget.controller;
    // `none` is the only state that renders nothing, and it is decided here
    // rather than outside the listener — a status that changes from `none` to
    // `ready` must rebuild the panel, which it cannot if the early return
    // happened before subscribing.
    if (controller.status == JobProofStatus.none ||
        controller.status == JobProofStatus.initial) {
      return const SizedBox.shrink();
    }

    if (controller.status == JobProofStatus.loading) {
      return FixCard(
        semanticLabel: 'Loading job photos',
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Loading job photos…',
              style: FixNowTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final heading = Text(
      'Work photos',
      style: FixNowTypography.h4.copyWith(color: AppColors.textPrimary),
    );

    switch (controller.status) {
      case JobProofStatus.error:
        return FixCard(
          semanticLabel: 'Job photos unavailable',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.xs),
              Text(
                controller.message ??
                    'Job photos are unavailable right now.',
                style: FixNowTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => controller.load(widget.bookingId),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 44),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        );

      case JobProofStatus.ready:
        return FixCard(
          semanticLabel: _comparisonLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              Text(
                'Captured by your pro on site. Drag to compare.',
                style: FixNowTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // The slider is drag-only, so it is described rather than relied
              // on: a screen-reader user gets the same fact in words.
              Semantics(
                label: _comparisonLabel,
                excludeSemantics: true,
                child: FixBeforeAfterSlider(
                  beforeBytes: controller.beforeBytes,
                  afterBytes: controller.afterBytes,
                  height: 220,
                ),
              ),
            ],
          ),
        );

      case JobProofStatus.partial:
        final missing = controller.missingSideLabel;
        return FixCard(
          semanticLabel:
              'One job photo is available. The $missing photo has not been '
              'uploaded.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.xs),
              // Named explicitly: an unnamed half is what makes an incomplete
              // proof look like a complete one.
              Text(
                'Your pro uploaded the '
                '${controller.hasBefore ? 'before' : 'after'} photo. '
                'The $missing photo has not been uploaded.',
                style: FixNowTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FixBeforeAfterSlider(
                beforeBytes: controller.hasBefore ? controller.beforeBytes : null,
                afterBytes: controller.hasAfter ? controller.afterBytes : null,
                height: 200,
              ),
            ],
          ),
        );

      case JobProofStatus.initial:
      case JobProofStatus.loading:
      case JobProofStatus.none:
        return const SizedBox.shrink();
    }
  }

  String get _comparisonLabel {
    final captured =
        widget.controller.beforeCapturedAt ?? widget.controller.afterCapturedAt;
    final when = captured == null
        ? ''
        : ' Captured ${_relative(captured)}.';
    return 'Before and after photos of the completed work.$when';
  }

  static String _relative(DateTime moment) {
    final gap = DateTime.now().difference(moment);
    if (gap.isNegative || gap.inMinutes < 1) return 'just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} minutes ago';
    if (gap.inHours < 24) return '${gap.inHours} hours ago';
    return '${gap.inDays} days ago';
  }
}