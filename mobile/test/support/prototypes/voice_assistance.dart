import 'package:permission_handler/permission_handler.dart';

enum VoiceInputState {
  idle,
  listening,
  processing,
  transcriptionReady,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  error,
}

class VoiceTranscription {
  const VoiceTranscription({
    required this.text,
    this.sourceLanguage = 'en',
    this.isLowConfidence = false,
  });

  final String text;
  final String sourceLanguage;
  final bool isLowConfidence;
}

abstract interface class VoiceRecognitionGateway {
  Future<bool> isAvailable();

  Future<VoiceTranscription> startListening();

  Future<void> stopListening();
}

/// Safe default until a reviewed platform recognizer is approved.
/// It captures and persists no audio, and never contacts a speech provider.
class UnsupportedVoiceRecognitionGateway implements VoiceRecognitionGateway {
  const UnsupportedVoiceRecognitionGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<VoiceTranscription> startListening() =>
      Future.error(const VoiceInputException.unavailable());

  @override
  Future<void> stopListening() async {}
}

class VoiceInputException implements Exception {
  const VoiceInputException._(this.kind);

  const VoiceInputException.unavailable() : this._(VoiceInputState.unavailable);
  const VoiceInputException.empty() : this._(VoiceInputState.error);

  final VoiceInputState kind;
}

abstract interface class MicrophonePermissionGateway {
  Future<PermissionStatus> status();

  Future<PermissionStatus> request();
}

class PermissionHandlerMicrophoneGateway
    implements MicrophonePermissionGateway {
  const PermissionHandlerMicrophoneGateway();

  @override
  Future<PermissionStatus> request() => Permission.microphone.request();

  @override
  Future<PermissionStatus> status() => Permission.microphone.status;
}

class VoiceInputController {
  VoiceInputController({
    VoiceRecognitionGateway? recognition,
    MicrophonePermissionGateway? permission,
  }) : _recognition = recognition ?? const UnsupportedVoiceRecognitionGateway(),
       _permission = permission ?? const PermissionHandlerMicrophoneGateway();

  final VoiceRecognitionGateway _recognition;
  final MicrophonePermissionGateway _permission;
  void Function()? onChanged;
  VoiceInputState state = VoiceInputState.idle;
  VoiceTranscription? transcription;

  Future<void> start() async {
    if (state == VoiceInputState.listening ||
        state == VoiceInputState.processing) {
      return;
    }
    if (!await _recognition.isAvailable()) {
      _setState(VoiceInputState.unavailable);
      return;
    }
    var permission = await _permission.status();
    if (permission.isDenied) permission = await _permission.request();
    if (permission.isPermanentlyDenied || permission.isRestricted) {
      _setState(VoiceInputState.permissionPermanentlyDenied);
      return;
    }
    if (!permission.isGranted) {
      _setState(VoiceInputState.permissionDenied);
      return;
    }
    _setState(VoiceInputState.listening);
    try {
      final result = await _recognition.startListening();
      _setState(VoiceInputState.processing);
      if (result.text.trim().isEmpty) throw const VoiceInputException.empty();
      transcription = result;
      _setState(VoiceInputState.transcriptionReady);
    } on VoiceInputException catch (error) {
      _setState(error.kind);
    } catch (_) {
      _setState(VoiceInputState.error);
    }
  }

  Future<void> stop() async {
    if (state != VoiceInputState.listening) return;
    _setState(VoiceInputState.processing);
    try {
      await _recognition.stopListening();
    } catch (_) {
      _setState(VoiceInputState.error);
    }
  }

  void reset() {
    transcription = null;
    _setState(VoiceInputState.idle);
  }

  void _setState(VoiceInputState value) {
    state = value;
    onChanged?.call();
  }
}

class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.processingText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  final String originalText;
  final String processingText;
  final String sourceLanguage;
  final String targetLanguage;

  bool get wasTranslated => sourceLanguage != targetLanguage;
}

abstract interface class TranslationGateway {
  Set<String> get supportedSourceLanguages;

  Future<TranslationResult> translate(VoiceTranscription transcription);
}

/// Only English is currently supported without an approved governed backend
/// translation provider. This deliberately performs no external data transfer.
class LocalOnlyTranslationGateway implements TranslationGateway {
  const LocalOnlyTranslationGateway();

  @override
  Set<String> get supportedSourceLanguages => const {'en'};

  @override
  Future<TranslationResult> translate(VoiceTranscription transcription) async {
    if (!supportedSourceLanguages.contains(transcription.sourceLanguage)) {
      throw const VoiceInputException.unavailable();
    }
    return TranslationResult(
      originalText: transcription.text,
      processingText: transcription.text,
      sourceLanguage: transcription.sourceLanguage,
      targetLanguage: 'en',
    );
  }
}
