import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/ai/ai_recommendation_repository.dart';
import 'package:fixnow_mobile/features/ai/voice_assistance.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';

class AiRecommendationScreen extends StatefulWidget {
  const AiRecommendationScreen({
    required this.repository,
    required this.categories,
    this.voiceInput,
    this.translation,
    super.key,
  });

  final AiRecommendationRepository repository;
  final List<ServiceCategory> categories;
  final VoiceInputController? voiceInput;
  final TranslationGateway? translation;

  @override
  State<AiRecommendationScreen> createState() => _AiRecommendationScreenState();
}

class _AiRecommendationScreenState extends State<AiRecommendationScreen> {
  final _input = TextEditingController();
  late final VoiceInputController _voice;
  late final TranslationGateway _translation;
  AiRecommendation? _result;
  TranslationResult? _translationResult;
  bool _loading = false;
  bool _translating = false;
  bool _needsTranscriptConfirmation = false;
  String? _error;
  String? _context;

  @override
  void initState() {
    super.initState();
    _voice = widget.voiceInput ?? VoiceInputController();
    _translation = widget.translation ?? const LocalOnlyTranslationGateway();
    _voice.onChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _voice.onChanged = null;
    _input.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    await _voice.start();
    final transcription = _voice.transcription;
    if (_voice.state != VoiceInputState.transcriptionReady ||
        transcription == null) {
      return;
    }
    setState(() => _translating = true);
    try {
      final translation = await _translation.translate(transcription);
      if (!mounted) return;
      setState(() {
        _translationResult = translation;
        _input.text = translation.processingText;
        _needsTranscriptConfirmation = true;
      });
    } on VoiceInputException {
      if (mounted) setState(() => _voice.reset());
    } catch (_) {
      if (mounted) setState(() => _voice.reset());
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _submit() async {
    if (_input.text.trim().isEmpty ||
        _loading ||
        _needsTranscriptConfirmation) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _result = await widget.repository.recommend(
        _input.text.trim(),
        context: _context,
      );
    } catch (_) {
      _error = "FixNow AI isn't available right now.";
    }
    if (mounted) setState(() => _loading = false);
  }

  void _recordAgain() {
    _translationResult = null;
    _needsTranscriptConfirmation = false;
    _input.clear();
    _voice.reset();
    setState(() {});
  }

  void _confirmTranscript() =>
      setState(() => _needsTranscriptConfirmation = false);

  void _reset() => setState(() {
    _result = null;
    _error = null;
    _context = null;
    _translationResult = null;
    _needsTranscriptConfirmation = false;
    _input.clear();
    _voice.reset();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ask FixNow AI')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Describe what's wrong and I'll help you find the right service.",
              semanticsLabel: 'Describe your issue for service guidance.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _input,
              maxLength: 1000,
              minLines: 4,
              maxLines: 6,
              enabled: !_loading && !_translating,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What needs fixing?',
                hintText: 'My sink is leaking',
              ),
            ),
            _voicePanel(),
            if (_translationResult != null) _transcriptReview(),
            const SizedBox(height: 12),
            FixButton(
              label: _loading
                  ? 'Understanding your issue...'
                  : 'Find the right service',
              onPressed:
                  _loading ||
                      _translating ||
                      _needsTranscriptConfirmation ||
                      _input.text.trim().isEmpty
                  ? null
                  : _submit,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Understanding your issue',
                  ),
                ),
              ),
            if (_error != null) _fallback(),
            if (_result != null) _resultCard(_result!),
          ],
        ),
      ),
    ),
  );

  Widget _voicePanel() {
    if (_voice.state == VoiceInputState.listening) {
      return FixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Listening...',
              semanticsLabel: 'Voice input is listening',
            ),
            const Text('Speak naturally. You can edit the text afterward.'),
            const SizedBox(height: 8),
            FixButton(
              label: 'Stop listening',
              onPressed: _voice.stop,
              variant: FixButtonVariant.secondary,
            ),
          ],
        ),
      );
    }
    if (_translating || _voice.state == VoiceInputState.processing) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Preparing your words...',
          semanticsLabel: 'Preparing voice transcription',
        ),
      );
    }
    final message = switch (_voice.state) {
      VoiceInputState.permissionDenied =>
        'Microphone access was denied. You can type your issue instead.',
      VoiceInputState.permissionPermanentlyDenied =>
        'Microphone access is blocked in your device settings. You can type your issue instead.',
      VoiceInputState.unavailable =>
        "Voice input isn't available on this device or browser. You can type your issue instead.",
      VoiceInputState.error =>
        "We couldn't understand any speech. You can try again or type your issue.",
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        FixButton(
          label: 'Speak your issue',
          icon: Icons.mic_none_rounded,
          variant: FixButtonVariant.secondary,
          onPressed: _loading || _translating ? null : _startVoice,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'You can review and edit your words before anything is submitted.',
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              semanticsLabel: 'Voice input status: $message',
            ),
          ),
      ],
    );
  }

  Widget _transcriptReview() {
    final translation = _translationResult!;
    return FixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('You said'),
          if (translation.wasTranslated)
            Text(
              'Translated from ${translation.sourceLanguage}',
              semanticsLabel: 'Translated from ${translation.sourceLanguage}',
            ),
          if (_voice.transcription?.isLowConfidence ?? false)
            const Text('Please review this carefully before continuing.'),
          const SizedBox(height: 8),
          Text(translation.originalText),
          const SizedBox(height: 8),
          FixButton(
            label: 'Use this description',
            onPressed: _confirmTranscript,
          ),
          TextButton(
            onPressed: _recordAgain,
            child: const Text('Record again'),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Column(
    children: [
      const SizedBox(height: 16),
      FixCard(child: const Text("FixNow AI isn't available right now.")),
      TextButton(onPressed: _submit, child: const Text('Try again')),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Browse services'),
      ),
    ],
  );

  Widget _resultCard(AiRecommendation result) {
    if (result.kind == 'UNAVAILABLE') return _fallback();
    if (result.kind == 'CLARIFICATION') {
      return FixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('I need one more detail'),
            const SizedBox(height: 8),
            Text(
              result.clarificationQuestion ??
                  'Please describe the issue differently.',
            ),
            TextButton(
              onPressed: () {
                _context = _input.text;
                _input.clear();
                setState(() => _result = null);
              },
              child: const Text('Continue'),
            ),
            TextButton(onPressed: _reset, child: const Text('Start over')),
          ],
        ),
      );
    }
    if (result.kind != 'RECOMMENDATION') {
      return FixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("I couldn't confidently match this to a service yet."),
            if (result.safetyNotice != null)
              Text(result.safetyNotice!, semanticsLabel: 'Safety notice'),
            TextButton(
              onPressed: _reset,
              child: const Text('Describe the issue differently'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Browse all services'),
            ),
          ],
        ),
      );
    }
    final category = widget.categories
        .where((item) => item.id == result.categoryId)
        .firstOrNull;
    if (category == null) return _fallback();
    return FixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECOMMENDED SERVICE'),
          Text(
            result.serviceName ?? category.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(result.reason ?? ''),
          const Text('Strong match'),
          if (result.safetyNotice != null)
            Text(result.safetyNotice!, semanticsLabel: 'Safety notice'),
          FixButton(
            label: 'Continue with ${category.name}',
            onPressed: () => Navigator.pop(context, category),
          ),
          TextButton(
            onPressed: _reset,
            child: const Text('Try another description'),
          ),
        ],
      ),
    );
  }
}
