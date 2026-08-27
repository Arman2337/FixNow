import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _NullTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: null);
}

/// A repository stub that returns a canned result (or throws) and records the
/// parts and language hint it was asked to upload. Extends the concrete
/// repository and overrides the analyze methods the controller calls.
class _FakeRepository extends ProblemAnalysisRepository {
  _FakeRepository() : super(_NullTransport());

  ProblemAnalysis? response;
  Object? error;

  MultipartFileData? lastImage;
  MultipartFileData? lastAudio;
  String? lastLanguageHint;
  int calls = 0;

  Future<ProblemAnalysis> _answer() async {
    calls += 1;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<ProblemAnalysis> analyzeImage({required MultipartFileData image}) {
    lastImage = image;
    return _answer();
  }

  @override
  Future<ProblemAnalysis> analyzeVoice({
    required MultipartFileData audio,
    String? languageHint,
  }) {
    lastAudio = audio;
    lastLanguageHint = languageHint;
    return _answer();
  }

  @override
  Future<ProblemAnalysis> analyzeCombined({
    required MultipartFileData image,
    required MultipartFileData audio,
    String? languageHint,
  }) {
    lastImage = image;
    lastAudio = audio;
    lastLanguageHint = languageHint;
    return _answer();
  }
}

class _FakeImageGateway implements ImageCaptureGateway {
  _FakeImageGateway(this.result);

  CapturedImage? result;
  Object? error;
  ImageSource? lastSource;

  @override
  Future<CapturedImage?> pick(ImageSource source) async {
    lastSource = source;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeAudioGateway implements AudioCaptureGateway {
  _FakeAudioGateway({this.granted = true, Uint8List? pcm})
    : pcm = pcm ?? Uint8List.fromList(List<int>.filled(64, 7));

  bool granted;
  Uint8List pcm;
  bool startCalled = false;
  bool cancelCalled = false;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> start() async => startCalled = true;

  @override
  Future<Uint8List> stop() async => pcm;

  @override
  Future<void> cancel() async => cancelCalled = true;

  @override
  Future<void> dispose() async => disposed = true;
}

CapturedImage _capturedImage() => CapturedImage(
  bytes: Uint8List.fromList(const [1, 2, 3, 4]),
  contentType: 'image/jpeg',
  fileName: 'photo.jpg',
);

ProblemAnalysis _analysis({String source = 'image'}) =>
    ProblemAnalysis.analysis(
      source: source,
      category: 'Plumbing',
      subcategory: 'Leak',
      problemSummary: 'A leak.',
      urgency: ProblemUrgency.medium,
      confidence: 0.9,
      confidenceBand: ProblemConfidenceBand.high,
      serviceCategoryId: 'cat-1',
      serviceName: 'Plumbing',
      safetyNotice: null,
    );

void main() {
  late _FakeRepository repository;
  late _FakeImageGateway imageGateway;
  late _FakeAudioGateway audioGateway;

  ProblemDiagnosisController build() => ProblemDiagnosisController(
    repository,
    imageGateway: imageGateway,
    audioGateway: audioGateway,
  );

  setUp(() {
    repository = _FakeRepository();
    imageGateway = _FakeImageGateway(_capturedImage());
    audioGateway = _FakeAudioGateway();
  });

  group('capture', () {
    test('pickImage stores the photo and returns to idle', () async {
      final controller = build();
      await controller.pickImage(ImageSource.camera);

      expect(imageGateway.lastSource, ImageSource.camera);
      expect(controller.hasImage, isTrue);
      expect(controller.imageBytes, isNotNull);
      expect(controller.status, DiagnosisStatus.idle);
      expect(controller.message, isNull);
    });

    test('a cancelled picker leaves prior state intact', () async {
      imageGateway = _FakeImageGateway(null);
      final controller = build();
      await controller.pickImage(ImageSource.gallery);

      expect(controller.hasImage, isFalse);
      expect(controller.status, DiagnosisStatus.idle);
      expect(controller.message, isNull);
    });

    test('a picker failure surfaces a friendly message, not the error',
        () async {
      imageGateway = _FakeImageGateway(null)..error = Exception('boom');
      final controller = build();
      await controller.pickImage(ImageSource.camera);

      expect(controller.hasImage, isFalse);
      expect(controller.status, DiagnosisStatus.idle);
      expect(controller.message, isNotNull);
      expect(controller.message, isNot(contains('boom')));
    });

    test('denied microphone permission yields a permissionDenied state',
        () async {
      audioGateway = _FakeAudioGateway(granted: false);
      final controller = build();
      await controller.startRecording();

      expect(controller.status, DiagnosisStatus.permissionDenied);
      expect(controller.isRecording, isFalse);
      expect(audioGateway.startCalled, isFalse);
    });

    test('recording then stopping wraps the PCM as a WAV payload', () async {
      final controller = build();
      await controller.startRecording();
      expect(controller.isRecording, isTrue);

      await controller.stopRecording();
      expect(controller.status, DiagnosisStatus.idle);
      expect(controller.hasAudio, isTrue);

      // Analyze to inspect the exact bytes handed to the repository.
      repository.response = _analysis(source: 'voice');
      await controller.analyzeVoice();
      final audio = repository.lastAudio!;
      expect(audio.fieldName, 'audio');
      expect(audio.fileName, 'recording.wav');
      expect(audio.contentType, 'audio/wav');
      expect(String.fromCharCodes(audio.bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(audio.bytes.sublist(8, 12)), 'WAVE');
      // 44-byte RIFF/WAVE header + the 64 PCM bytes from the fake gateway.
      expect(audio.bytes.length, 44 + 64);
    });

    test('an empty recording is discarded with a message', () async {
      audioGateway = _FakeAudioGateway(pcm: Uint8List(0));
      final controller = build();
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.hasAudio, isFalse);
      expect(controller.message, isNotNull);
      expect(controller.status, DiagnosisStatus.idle);
    });

    test('cancelRecording drops the take and returns to idle', () async {
      final controller = build();
      await controller.startRecording();
      await controller.cancelRecording();

      expect(audioGateway.cancelCalled, isTrue);
      expect(controller.hasAudio, isFalse);
      expect(controller.status, DiagnosisStatus.idle);
    });
  });

  group('analyze', () {
    test('a successful image analysis moves to the result state', () async {
      repository.response = _analysis();
      final controller = build();
      await controller.pickImage(ImageSource.camera);
      await controller.analyzeImage();

      expect(controller.status, DiagnosisStatus.result);
      expect(controller.result!.isAnalysis, isTrue);
      expect(repository.lastImage!.fieldName, 'image');
      expect(repository.lastImage!.bytes, _capturedImage().bytes);
    });

    test('an ApiException degrades to the unavailable state', () async {
      repository.error = const ApiException(ApiFailureKind.server, 'upstream');
      final controller = build();
      await controller.pickImage(ImageSource.camera);
      await controller.analyzeImage();

      expect(controller.status, DiagnosisStatus.unavailable);
      expect(controller.result, isNull);
    });

    test('a FormatException also degrades to unavailable', () async {
      repository.error = const FormatException('bad json');
      final controller = build();
      await controller.pickImage(ImageSource.camera);
      await controller.analyzeImage();

      expect(controller.status, DiagnosisStatus.unavailable);
    });

    test('an unavailable analysis result is surfaced as unavailable', () async {
      repository.response = const ProblemAnalysis.unavailable(
        source: 'image',
        errorCode: 'AI_DISABLED',
      );
      final controller = build();
      await controller.pickImage(ImageSource.camera);
      await controller.analyzeImage();

      expect(controller.status, DiagnosisStatus.unavailable);
      expect(controller.result!.isAnalysis, isFalse);
    });

    test('analyzeImage without a photo is a no-op', () async {
      final controller = build();
      await controller.analyzeImage();

      expect(repository.calls, 0);
      expect(controller.status, DiagnosisStatus.idle);
    });

    test('the selected language becomes the hint; auto omits it', () async {
      repository.response = _analysis(source: 'voice');
      final controller = build();
      await controller.startRecording();
      await controller.stopRecording();

      controller.setLanguage(DiagnosisLanguage.hindi);
      await controller.analyzeVoice();
      expect(repository.lastLanguageHint, 'hi');

      controller.setLanguage(DiagnosisLanguage.auto);
      await controller.analyzeVoice();
      expect(repository.lastLanguageHint, isNull);
    });

    test('combined analysis requires both a photo and audio', () async {
      repository.response = _analysis(source: 'image_voice');
      final controller = build();

      await controller.analyzeCombined();
      expect(repository.calls, 0);

      await controller.pickImage(ImageSource.camera);
      await controller.startRecording();
      await controller.stopRecording();
      await controller.analyzeCombined();

      expect(repository.calls, 1);
      expect(repository.lastImage, isNotNull);
      expect(repository.lastAudio, isNotNull);
      expect(controller.status, DiagnosisStatus.result);
    });

    test('reset clears media, result, and message', () async {
      repository.response = _analysis();
      final controller = build();
      await controller.pickImage(ImageSource.camera);
      await controller.analyzeImage();
      controller.reset();

      expect(controller.hasImage, isFalse);
      expect(controller.hasAudio, isFalse);
      expect(controller.result, isNull);
      expect(controller.message, isNull);
      expect(controller.status, DiagnosisStatus.idle);
    });
  });
}
