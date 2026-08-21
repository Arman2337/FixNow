import 'dart:async';

import 'package:fixnow_mobile/features/ai/voice_assistance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class _Permission implements MicrophonePermissionGateway {
  _Permission(this.value, {this.afterRequest});

  PermissionStatus value;
  PermissionStatus? afterRequest;
  var requests = 0;

  @override
  Future<PermissionStatus> request() async {
    requests += 1;
    return value = afterRequest ?? value;
  }

  @override
  Future<PermissionStatus> status() async => value;
}

class _Recognition implements VoiceRecognitionGateway {
  _Recognition({this.available = true, this.result});

  final bool available;
  final Future<VoiceTranscription>? result;
  var starts = 0;
  var stops = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<VoiceTranscription> startListening() {
    starts += 1;
    return result ??
        Future.value(const VoiceTranscription(text: 'My sink leaks'));
  }

  @override
  Future<void> stopListening() async {
    stops += 1;
  }
}

void main() {
  test(
    'unavailable recognition does not request microphone permission',
    () async {
      final permission = _Permission(PermissionStatus.denied);
      final controller = VoiceInputController(
        recognition: _Recognition(available: false),
        permission: permission,
      );

      await controller.start();

      expect(controller.state, VoiceInputState.unavailable);
      expect(permission.requests, 0);
    },
  );

  test('granted permission produces an editable transcription only', () async {
    final controller = VoiceInputController(
      recognition: _Recognition(),
      permission: _Permission(PermissionStatus.granted),
    );

    await controller.start();

    expect(controller.state, VoiceInputState.transcriptionReady);
    expect(controller.transcription!.text, 'My sink leaks');
  });

  test(
    'denied and permanently denied microphone permissions stay recoverable',
    () async {
      final denied = VoiceInputController(
      recognition: _Recognition(),
      permission: _Permission(
        PermissionStatus.denied,
        afterRequest: PermissionStatus.denied,
      ),
      );
      await denied.start();
      expect(denied.state, VoiceInputState.permissionDenied);

      final permanent = VoiceInputController(
        recognition: _Recognition(),
        permission: _Permission(PermissionStatus.permanentlyDenied),
      );
      await permanent.start();
      expect(permanent.state, VoiceInputState.permissionPermanentlyDenied);
    },
  );

  test(
    'empty speech and duplicate starts never create a second listening session',
    () async {
      final pending = Completer<VoiceTranscription>();
      final recognition = _Recognition(result: pending.future);
      final controller = VoiceInputController(
        recognition: recognition,
        permission: _Permission(PermissionStatus.granted),
      );

      final first = controller.start();
      await Future<void>.delayed(Duration.zero);
      await controller.start();
      expect(recognition.starts, 1);
      await controller.stop();
      expect(recognition.stops, 1);
      pending.complete(const VoiceTranscription(text: ''));
      await first;
      expect(controller.state, VoiceInputState.error);
    },
  );

  test(
    'local translation preserves original text and rejects unsupported languages',
    () async {
      const gateway = LocalOnlyTranslationGateway();
      final english = await gateway.translate(
        const VoiceTranscription(text: 'My kitchen pipe leaks'),
      );
      expect(english.originalText, 'My kitchen pipe leaks');
      expect(english.processingText, english.originalText);
      expect(english.wasTranslated, isFalse);

      await expectLater(
        gateway.translate(
          const VoiceTranscription(text: 'લીક છે', sourceLanguage: 'gu'),
        ),
        throwsA(isA<VoiceInputException>()),
      );
    },
  );
}
