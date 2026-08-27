import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_screen.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'pump_idle.dart';

const _plumbing = ServiceCategory(
  id: 'plumbing',
  name: 'Plumbing',
  slug: 'plumbing',
);

/// A valid 1x1 transparent PNG, so `Image.memory` decodes without error.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8A'
  'AAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

class _NullTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: null);
}

class _StubRepository extends ProblemAnalysisRepository {
  _StubRepository(this.response) : super(_NullTransport());

  final ProblemAnalysis response;

  @override
  Future<ProblemAnalysis> analyzeImage({required MultipartFileData image}) async =>
      response;
}

class _StubImageGateway implements ImageCaptureGateway {
  @override
  Future<CapturedImage?> pick(ImageSource source) async => CapturedImage(
    bytes: Uint8List.fromList(_pngBytes),
    contentType: 'image/png',
    fileName: 'photo.png',
  );
}

class _StubAudioGateway implements AudioCaptureGateway {
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<Uint8List> stop() async => Uint8List(0);
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

ProblemAnalysis _analysis({
  required String? serviceCategoryId,
  ProblemConfidenceBand band = ProblemConfidenceBand.high,
}) => ProblemAnalysis.analysis(
  source: 'image',
  category: 'Plumbing',
  subcategory: 'Leak',
  problemSummary: 'A leak under the sink.',
  urgency: ProblemUrgency.medium,
  confidence: 0.9,
  confidenceBand: band,
  serviceCategoryId: serviceCategoryId,
  serviceName: serviceCategoryId == null ? null : 'Plumbing',
  safetyNotice: null,
);

class _Launcher extends StatefulWidget {
  const _Launcher({required this.response});
  final ProblemAnalysis response;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _result = 'not-opened';

  Future<void> _open() async {
    final selected = await Navigator.of(context).push<ServiceCategory>(
      MaterialPageRoute(
        builder: (_) => ProblemDiagnosisScreen(
          controller: ProblemDiagnosisController(
            _StubRepository(widget.response),
            imageGateway: _StubImageGateway(),
            audioGateway: _StubAudioGateway(),
          ),
          categories: const [_plumbing],
        ),
      ),
    );
    if (mounted) setState(() => _result = selected?.id ?? 'none');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        FilledButton(onPressed: _open, child: const Text('Open')),
        Text('returned:$_result'),
      ],
    ),
  );
}

/// Scrolls a target in the (tall) scroll view into view before tapping it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpIdle();
  await tester.tap(finder);
  await tester.pumpIdle();
}

Future<void> _openAndAttachPhoto(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpIdle();

  // Analyze stays disabled until something is attached.
  expect(
    tester.widget<FixButton>(find.widgetWithText(FixButton, 'Analyze')).onPressed,
    isNull,
  );

  await tester.tap(find.text('Add photo'));
  await tester.pumpIdle();
  await tester.tap(find.text('Take a photo'));
  await tester.pumpIdle();

  await _tap(tester, find.text('Analyze'));
}

void main() {
  testWidgets('a high-confidence match offers to book and hands back the '
      'category', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Launcher(response: _analysis(serviceCategoryId: 'plumbing')),
      ),
    );
    await _openAndAttachPhoto(tester);

    expect(find.text('Book Plumbing'), findsOneWidget);
    await _tap(tester, find.text('Book Plumbing'));

    expect(find.text('returned:plumbing'), findsOneWidget);
  });

  testWidgets('an ungrounded result falls back to browsing and pops nothing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Launcher(response: _analysis(serviceCategoryId: null)),
      ),
    );
    await _openAndAttachPhoto(tester);

    expect(find.text('Browse services'), findsOneWidget);
    await _tap(tester, find.text('Browse services'));

    expect(find.text('returned:none'), findsOneWidget);
  });
}
