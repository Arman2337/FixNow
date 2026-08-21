import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/ai/ai_recommendation_repository.dart';
import 'package:fixnow_mobile/features/ai/ai_recommendation_screen.dart';
import 'package:fixnow_mobile/features/ai/voice_assistance.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

const _plumbing = ServiceCategory(
  id: 'plumbing',
  name: 'Plumbing',
  slug: 'plumbing',
);

class _QueueTransport implements ApiTransport {
  _QueueTransport(this.responses);

  final List<Future<ApiResponse> Function(ApiRequest)> responses;
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) {
    requests.add(request);
    return responses.removeAt(0)(request);
  }
}

class _GrantedMicrophone implements MicrophonePermissionGateway {
  @override
  Future<PermissionStatus> request() async => PermissionStatus.granted;

  @override
  Future<PermissionStatus> status() async => PermissionStatus.granted;
}

class _VoiceRecognition implements VoiceRecognitionGateway {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VoiceTranscription> startListening() async => const VoiceTranscription(
    text: 'મારા રસોડામાં પાઇપ લીક થાય છે',
    sourceLanguage: 'gu',
  );

  @override
  Future<void> stopListening() async {}
}

class _Translation implements TranslationGateway {
  @override
  Set<String> get supportedSourceLanguages => const {'gu'};

  @override
  Future<TranslationResult> translate(VoiceTranscription transcription) async =>
      TranslationResult(
        originalText: transcription.text,
        processingText: 'My kitchen pipe is leaking.',
        sourceLanguage: 'gu',
        targetLanguage: 'en',
      );
}

class _Launcher extends StatefulWidget {
  const _Launcher({
    required this.repository,
    this.voiceInput,
    this.translation,
  });
  final AiRecommendationRepository repository;
  final VoiceInputController? voiceInput;
  final TranslationGateway? translation;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _result = 'not-opened';

  Future<void> _open() async {
    final selected = await Navigator.of(context).push<ServiceCategory>(
      MaterialPageRoute(
        builder: (_) => AiRecommendationScreen(
          repository: widget.repository,
          categories: const [_plumbing],
          voiceInput: widget.voiceInput,
          translation: widget.translation,
        ),
      ),
    );
    if (mounted) setState(() => _result = selected?.id ?? 'none');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        FilledButton(onPressed: _open, child: const Text('Open assistant')),
        Text('returned:$_result'),
      ],
    ),
  );
}

Widget _app(
  _QueueTransport transport, {
  VoiceInputController? voiceInput,
  TranslationGateway? translation,
}) => MaterialApp(
  home: _Launcher(
    repository: AiRecommendationRepository(transport, () async => 'token'),
    voiceInput: voiceInput,
    translation: translation,
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open assistant'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keeps submit disabled until issue text is provided', (
    tester,
  ) async {
    final transport = _QueueTransport([]);
    await tester.pumpWidget(_app(transport));
    await _open(tester);

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Find the right service'),
    );
    expect(submit.onPressed, isNull);
    expect(
      find.bySemanticsLabel('Describe your issue for service guidance.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows loading once and returns a selected category without booking',
    (tester) async {
      final response = Completer<ApiResponse>();
      final transport = _QueueTransport([(_) => response.future]);
      await tester.pumpWidget(_app(transport));
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'My kitchen sink leaks');
      await tester.pump();
      await tester.tap(find.text('Find the right service'));
      await tester.pump();
      expect(find.text('Understanding your issue...'), findsOneWidget);
      expect(find.bySemanticsLabel('Understanding your issue'), findsOneWidget);
      await tester.tap(find.text('Understanding your issue...'));
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.path, 'ai/service-recommendation');
      expect(transport.requests.single.body, {
        'description': 'My kitchen sink leaks',
      });

      response.complete(
        const ApiResponse(
          statusCode: 200,
          body: {
            'kind': 'RECOMMENDATION',
            'recommendation': {
              'serviceCategoryId': 'plumbing',
              'serviceName': 'Plumbing',
              'reason': 'This sounds like a pipe or fixture leak.',
            },
            'safetyNotice': 'Turn off water if it is safe to do so.',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RECOMMENDED SERVICE'), findsOneWidget);
      expect(
        find.text('This sounds like a pipe or fixture leak.'),
        findsOneWidget,
      );
      expect(
        find.text('Turn off water if it is safe to do so.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue with Plumbing'));
      await tester.pumpAndSettle();
      expect(find.text('returned:plumbing'), findsOneWidget);
      expect(transport.requests, hasLength(1));
    },
  );

  testWidgets('supports clarification and a safe no-match browse fallback', (
    tester,
  ) async {
    final transport = _QueueTransport([
      (_) async => const ApiResponse(
        statusCode: 200,
        body: {
          'kind': 'CLARIFICATION',
          'clarificationQuestion': 'What type of machine is making the sound?',
          'safetyNotice': null,
        },
      ),
      (_) async => const ApiResponse(
        statusCode: 200,
        body: {
          'kind': 'NO_MATCH',
          'safetyNotice':
              'Move away from danger and contact local emergency services if needed.',
        },
      ),
    ]);
    await tester.pumpWidget(_app(transport));
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'A machine is noisy');
    await tester.pump();
    await tester.tap(find.text('Find the right service'));
    await tester.pumpAndSettle();
    expect(find.text('I need one more detail'), findsOneWidget);
    expect(
      find.text('What type of machine is making the sound?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('I need one more detail'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );

    await tester.enterText(find.byType(TextField), 'I smell gas');
    await tester.pump();
    await tester.tap(find.text('Find the right service'));
    await tester.pumpAndSettle();
    expect(
      find.text("I couldn't confidently match this to a service yet."),
      findsOneWidget,
    );
    expect(
      find.text(
        'Move away from danger and contact local emergency services if needed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Browse all services'));
    await tester.pumpAndSettle();
    expect(find.text('returned:none'), findsOneWidget);
  });

  testWidgets('uses a friendly unavailable state without exposing API errors', (
    tester,
  ) async {
    final transport = _QueueTransport([
      (_) => Future<ApiResponse>.error(
        const ApiException(ApiFailureKind.server, 'raw upstream error'),
      ),
    ]);
    await tester.pumpWidget(_app(transport));
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'My sink leaks');
    await tester.pump();
    await tester.tap(find.text('Find the right service'));
    await tester.pumpAndSettle();
    expect(find.text("FixNow AI isn't available right now."), findsOneWidget);
    expect(find.textContaining('raw upstream error'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Browse services'), findsOneWidget);
  });

  testWidgets('requires transcript confirmation before voice enters FN-057', (
    tester,
  ) async {
    final transport = _QueueTransport([]);
    final voice = VoiceInputController(
      recognition: _VoiceRecognition(),
      permission: _GrantedMicrophone(),
    );
    await tester.pumpWidget(
      _app(transport, voiceInput: voice, translation: _Translation()),
    );
    await _open(tester);

    expect(find.bySemanticsLabel('Speak your issue'), findsOneWidget);
    await tester.tap(find.text('Speak your issue'));
    await tester.pumpAndSettle();
    expect(find.text('You said'), findsOneWidget);
    expect(find.text('Translated from gu'), findsOneWidget);
    expect(find.text('મારા રસોડામાં પાઇપ લીક થાય છે'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My kitchen pipe is leaking.',
    );
    expect(transport.requests, isEmpty);

    await tester.tap(find.text('Use this description'));
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Find the right service'),
    );
    expect(submit.onPressed, isNotNull);
    expect(transport.requests, isEmpty);
  });
}
