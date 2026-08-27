import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// "Diagnose your problem": capture a photo and/or a spoken description, send it
/// once to the governed backend, and offer a confidence-banded suggestion that
/// hands a matched service category back to the booking flow. Every failure
/// degrades to manual "Browse services" — it never blocks the customer.
///
/// The screen takes ownership of [controller] and disposes it.
class ProblemDiagnosisScreen extends StatefulWidget {
  const ProblemDiagnosisScreen({
    required this.controller,
    required this.categories,
    super.key,
  });

  final ProblemDiagnosisController controller;
  final List<ServiceCategory> categories;

  @override
  State<ProblemDiagnosisScreen> createState() => _ProblemDiagnosisScreenState();
}

class _ProblemDiagnosisScreenState extends State<ProblemDiagnosisScreen> {
  ProblemDiagnosisController get _controller => widget.controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _controller.pickImage(source);
  }

  /// Dispatch to the endpoint matching whatever the customer attached.
  Future<void> _analyze() async {
    final controller = _controller;
    if (controller.hasImage && controller.hasAudio) {
      await controller.analyzeCombined();
    } else if (controller.hasImage) {
      await controller.analyzeImage();
    } else if (controller.hasAudio) {
      await controller.analyzeVoice();
    }
  }

  ServiceCategory? _matchedCategory(ProblemAnalysis analysis) {
    final id = analysis.serviceCategoryId;
    if (id == null) return null;
    return widget.categories.where((item) => item.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diagnose your problem')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a photo of the problem, describe it out loud, or both. '
                "We'll suggest the right service — you always confirm before booking.",
              ),
              const SizedBox(height: AppSpacing.lg),
              _photoSection(),
              const SizedBox(height: AppSpacing.lg),
              _voiceSection(),
              const SizedBox(height: AppSpacing.lg),
              _languageSelector(),
              const SizedBox(height: AppSpacing.lg),
              FixButton(
                label: 'Analyze',
                icon: Icons.auto_awesome_rounded,
                expand: true,
                isLoading: _controller.isAnalyzing,
                onPressed:
                    (_controller.hasImage || _controller.hasAudio) &&
                        !_controller.isAnalyzing &&
                        !_controller.isRecording
                    ? _analyze
                    : null,
              ),
              if (_controller.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _controller.message!,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _statusArea(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _photoSection() {
    final bytes = _controller.imageBytes;
    if (bytes != null) {
      return FixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Image.memory(
                bytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Photo of the problem you added',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FixButton(
                    label: 'Replace',
                    variant: FixButtonVariant.secondary,
                    onPressed: _controller.isAnalyzing ? null : _addPhoto,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FixButton(
                    label: 'Remove',
                    variant: FixButtonVariant.tertiary,
                    onPressed: _controller.isAnalyzing
                        ? null
                        : _controller.clearImage,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return FixButton(
      label: 'Add photo',
      icon: Icons.add_a_photo_rounded,
      variant: FixButtonVariant.secondary,
      expand: true,
      onPressed: _controller.isAnalyzing || _controller.isRecording
          ? null
          : _addPhoto,
    );
  }

  Widget _voiceSection() {
    if (_controller.isRecording) {
      return FixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.fiber_manual_record_rounded, color: AppColors.danger),
                SizedBox(width: AppSpacing.sm),
                Text('Recording… describe the problem.'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FixButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    onPressed: _controller.stopRecording,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FixButton(
                    label: 'Cancel',
                    variant: FixButtonVariant.tertiary,
                    onPressed: _controller.cancelRecording,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_controller.hasAudio) {
      return FixCard(
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Voice description recorded')),
            TextButton(
              onPressed: _controller.isAnalyzing ? null : _controller.clearAudio,
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
    if (_controller.status == DiagnosisStatus.permissionDenied) {
      return FixCard(
        tone: FixCardTone.secondary,
        child: Text(
          _controller.message ??
              'Microphone access is needed. Enable it in Settings.',
        ),
      );
    }
    return FixButton(
      label: 'Record voice',
      icon: Icons.mic_rounded,
      variant: FixButtonVariant.secondary,
      expand: true,
      onPressed: _controller.isAnalyzing ? null : _controller.startRecording,
    );
  }

  Widget _languageSelector() {
    const labels = {
      DiagnosisLanguage.auto: 'Auto',
      DiagnosisLanguage.english: 'English',
      DiagnosisLanguage.hindi: 'Hindi',
      DiagnosisLanguage.gujarati: 'Gujarati',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spoken language',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final entry in labels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _controller.language == entry.key,
                onSelected: _controller.isAnalyzing
                    ? null
                    : (_) => _controller.setLanguage(entry.key),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusArea() {
    switch (_controller.status) {
      case DiagnosisStatus.analyzing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            FixSkeleton(height: 20, width: 160),
            SizedBox(height: AppSpacing.sm),
            FixSkeleton(height: 72),
            SizedBox(height: AppSpacing.sm),
            FixSkeleton(height: 52),
          ],
        );
      case DiagnosisStatus.unavailable:
        return _fallback();
      case DiagnosisStatus.result:
        final analysis = _controller.result;
        if (analysis == null || !analysis.isAnalysis) return _fallback();
        return _resultCard(analysis);
      case DiagnosisStatus.idle:
      case DiagnosisStatus.capturing:
      case DiagnosisStatus.recording:
      case DiagnosisStatus.permissionDenied:
        return const SizedBox.shrink();
    }
  }

  Widget _resultCard(ProblemAnalysis analysis) {
    final matched = _matchedCategory(analysis);
    final band = analysis.confidenceBand ?? ProblemConfidenceBand.low;
    final canSuggest = matched != null && band != ProblemConfidenceBand.low;

    return FixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (analysis.serviceName ?? analysis.category ?? 'Suggested service'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (analysis.subcategory != null &&
              analysis.subcategory != 'Other') ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              analysis.subcategory!,
              style: const TextStyle(color: AppColors.textOnSurfaceSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (analysis.urgency != null) _urgencyChip(analysis.urgency!),
              _bandChip(band),
            ],
          ),
          if (analysis.problemSummary != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(analysis.problemSummary!),
          ],
          if (analysis.transcription != null &&
              analysis.transcription!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'You said',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              analysis.transcription!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          if (analysis.safetyNotice != null) ...[
            const SizedBox(height: AppSpacing.md),
            _safetyBanner(analysis.safetyNotice!),
          ],
          const SizedBox(height: AppSpacing.lg),
          ..._resultActions(analysis, matched, band, canSuggest),
        ],
      ),
    );
  }

  List<Widget> _resultActions(
    ProblemAnalysis analysis,
    ServiceCategory? matched,
    ProblemConfidenceBand band,
    bool canSuggest,
  ) {
    if (!canSuggest || matched == null) {
      // Low confidence or no bookable match: keep the ordinary manual flow.
      return [
        const Text(
          "We couldn't confidently match this. You can browse services instead.",
          style: TextStyle(color: AppColors.textOnSurfaceSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        FixButton(
          label: 'Browse services',
          expand: true,
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          onPressed: _controller.reset,
          child: const Text('Start over'),
        ),
      ];
    }
    if (band == ProblemConfidenceBand.high) {
      return [
        FixButton(
          label: 'Book ${matched.name}',
          trailingIcon: Icons.arrow_forward_rounded,
          expand: true,
          onPressed: () => Navigator.pop(context, matched),
        ),
        TextButton(
          onPressed: _controller.reset,
          child: const Text('Start over'),
        ),
      ];
    }
    // Medium: suggest but ask the customer to confirm.
    return [
      Text('Looks like ${matched.name} — does that sound right?'),
      const SizedBox(height: AppSpacing.sm),
      FixButton(
        label: 'Confirm & continue',
        expand: true,
        onPressed: () => Navigator.pop(context, matched),
      ),
      const SizedBox(height: AppSpacing.xs),
      FixButton(
        label: 'Choose another service',
        variant: FixButtonVariant.secondary,
        expand: true,
        onPressed: () => Navigator.pop(context),
      ),
      TextButton(
        onPressed: _controller.reset,
        child: const Text('Start over'),
      ),
    ];
  }

  Widget _fallback() => FixEmptyState(
    icon: Icons.search_rounded,
    title: "Couldn't auto-detect the problem",
    message:
        "No problem — you can pick a service yourself and we'll take it from there.",
    actionLabel: 'Browse services',
    onAction: () => Navigator.pop(context),
  );

  Widget _urgencyChip(ProblemUrgency urgency) {
    final (label, color, background) = switch (urgency) {
      ProblemUrgency.high => ('High urgency', AppColors.danger, AppColors.dangerSoft),
      ProblemUrgency.medium => ('Medium urgency', AppColors.warning, AppColors.warningSoft),
      ProblemUrgency.low => ('Low urgency', AppColors.success, AppColors.successSoft),
    };
    return _Chip(label: label, foreground: color, background: background);
  }

  Widget _bandChip(ProblemConfidenceBand band) {
    final (label, color, background) = switch (band) {
      ProblemConfidenceBand.high => ('High confidence', AppColors.success, AppColors.successSoft),
      ProblemConfidenceBand.medium => ('Medium confidence', AppColors.warning, AppColors.warningSoft),
      ProblemConfidenceBand.low => ('Low confidence', AppColors.textOnSurfaceSecondary, AppColors.surfaceSecondary),
    };
    return _Chip(label: label, foreground: color, background: background);
  }

  Widget _safetyBanner(String notice) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(color: AppColors.warning),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            notice,
            style: const TextStyle(color: AppColors.textOnSurface),
            semanticsLabel: 'Safety notice: $notice',
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
