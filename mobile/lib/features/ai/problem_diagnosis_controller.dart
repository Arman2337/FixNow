import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

/// PCM capture format. The WAV header written on stop MUST describe the same
/// values, so they are declared once and shared by the recorder config and the
/// header builder.
const int _kSampleRate = 16000;
const int _kNumChannels = 1;
const int _kBitsPerSample = 16;

/// Controls the multimodal "Diagnose your problem" flow: capture a photo and/or
/// a spoken description entirely in memory, then upload once to the governed
/// backend and expose a confidence-banded result. Capture is behind injectable
/// gateways so tests run without camera or microphone hardware.
class ProblemDiagnosisController extends ChangeNotifier {
  ProblemDiagnosisController(
    this._repository, {
    ImageCaptureGateway? imageGateway,
    AudioCaptureGateway? audioGateway,
  }) : _imageGateway = imageGateway ?? ImagePickerImageGateway(),
       _audioGateway = audioGateway ?? RecordAudioGateway();

  final ProblemAnalysisRepository _repository;
  final ImageCaptureGateway _imageGateway;
  final AudioCaptureGateway _audioGateway;

  DiagnosisStatus status = DiagnosisStatus.idle;
  ProblemAnalysis? result;

  /// A short, non-fatal note for the UI (e.g. capture failed). Never raw media.
  String? message;

  DiagnosisLanguage language = DiagnosisLanguage.auto;

  CapturedImage? _image;
  Uint8List? _audioWav;

  Uint8List? get imageBytes => _image?.bytes;
  bool get hasImage => _image != null;
  bool get hasAudio => _audioWav != null;
  bool get isRecording => status == DiagnosisStatus.recording;
  bool get isAnalyzing => status == DiagnosisStatus.analyzing;

  void setLanguage(DiagnosisLanguage value) {
    language = value;
    notifyListeners();
  }

  /// Capture or select a photo. A cancelled picker leaves prior state intact.
  Future<void> pickImage(ImageSource source) async {
    status = DiagnosisStatus.capturing;
    message = null;
    notifyListeners();
    try {
      final captured = await _imageGateway.pick(source);
      if (captured != null) _image = captured;
    } catch (_) {
      message = 'Could not add the photo. Please try again.';
    }
    status = DiagnosisStatus.idle;
    notifyListeners();
  }

  Future<void> startRecording() async {
    final granted = await _audioGateway.hasPermission();
    if (!granted) {
      status = DiagnosisStatus.permissionDenied;
      message = 'Microphone access is needed. Enable it in Settings.';
      notifyListeners();
      return;
    }
    try {
      await _audioGateway.start();
      status = DiagnosisStatus.recording;
      message = null;
    } catch (_) {
      status = DiagnosisStatus.idle;
      message = 'Could not start recording.';
    }
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (status != DiagnosisStatus.recording) return;
    try {
      final pcm = await _audioGateway.stop();
      _audioWav = pcm.isEmpty ? null : _wrapPcmAsWav(pcm);
      if (_audioWav == null) message = 'No audio captured. Please try again.';
    } catch (_) {
      message = 'Could not finish recording.';
    }
    status = DiagnosisStatus.idle;
    notifyListeners();
  }

  Future<void> cancelRecording() async {
    if (status != DiagnosisStatus.recording) return;
    await _audioGateway.cancel();
    status = DiagnosisStatus.idle;
    notifyListeners();
  }

  void clearImage() {
    _image = null;
    notifyListeners();
  }

  void clearAudio() {
    _audioWav = null;
    notifyListeners();
  }

  /// Clear captured media and any result back to the initial state.
  void reset() {
    _image = null;
    _audioWav = null;
    result = null;
    message = null;
    status = DiagnosisStatus.idle;
    notifyListeners();
  }

  Future<void> analyzeImage() async {
    final image = _image;
    if (image == null) return;
    await _analyze(() => _repository.analyzeImage(image: _imagePart(image)));
  }

  Future<void> analyzeVoice() async {
    final audio = _audioWav;
    if (audio == null) return;
    await _analyze(
      () => _repository.analyzeVoice(
        audio: _audioPart(audio),
        languageHint: _languageHint,
      ),
    );
  }

  Future<void> analyzeCombined() async {
    final image = _image;
    final audio = _audioWav;
    if (image == null || audio == null) return;
    await _analyze(
      () => _repository.analyzeCombined(
        image: _imagePart(image),
        audio: _audioPart(audio),
        languageHint: _languageHint,
      ),
    );
  }

  /// Shared request lifecycle, mirroring the price-estimate controller: any
  /// failure degrades to `unavailable` so the UI always offers manual browsing.
  Future<void> _analyze(Future<ProblemAnalysis> Function() request) async {
    status = DiagnosisStatus.analyzing;
    result = null;
    message = null;
    notifyListeners();
    try {
      final analysis = await request();
      result = analysis;
      status = analysis.isAnalysis
          ? DiagnosisStatus.result
          : DiagnosisStatus.unavailable;
    } on ApiException {
      status = DiagnosisStatus.unavailable;
    } on FormatException {
      status = DiagnosisStatus.unavailable;
    }
    notifyListeners();
  }

  String? get _languageHint => _languageCode(language);

  MultipartFileData _imagePart(CapturedImage image) => MultipartFileData(
    fieldName: 'image',
    fileName: image.fileName,
    contentType: image.contentType,
    bytes: image.bytes,
  );

  MultipartFileData _audioPart(Uint8List wav) => MultipartFileData(
    fieldName: 'audio',
    fileName: 'recording.wav',
    contentType: 'audio/wav',
    bytes: wav,
  );

  @override
  void dispose() {
    unawaited(_audioGateway.dispose());
    super.dispose();
  }
}

enum DiagnosisStatus {
  idle,
  capturing,
  recording,
  analyzing,
  result,
  unavailable,
  permissionDenied,
}

/// Optional transcription/classification language steer. `auto` omits the
/// backend field entirely (best-effort auto-detect).
enum DiagnosisLanguage { auto, english, hindi, gujarati }

String? _languageCode(DiagnosisLanguage language) {
  switch (language) {
    case DiagnosisLanguage.auto:
      return null;
    case DiagnosisLanguage.english:
      return 'en';
    case DiagnosisLanguage.hindi:
      return 'hi';
    case DiagnosisLanguage.gujarati:
      return 'gu';
  }
}

/// A photo held in memory only — never written to disk or persisted.
class CapturedImage {
  const CapturedImage({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String fileName;
}

abstract interface class ImageCaptureGateway {
  /// Returns the captured image, or `null` if the user cancelled.
  Future<CapturedImage?> pick(ImageSource source);
}

/// Real capture via `image_picker`. `imageQuality` re-encodes to JPEG, which
/// both shrinks the payload and drops most EXIF metadata.
class ImagePickerImageGateway implements ImageCaptureGateway {
  ImagePickerImageGateway([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CapturedImage?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return CapturedImage(
      bytes: bytes,
      contentType: file.mimeType ?? _contentTypeForName(file.name),
      fileName: file.name.isEmpty ? 'photo.jpg' : file.name,
    );
  }

  static String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

abstract interface class AudioCaptureGateway {
  Future<bool> hasPermission();
  Future<void> start();

  /// Returns the raw little-endian PCM (s16, mono, 16 kHz) captured since start.
  Future<Uint8List> stop();
  Future<void> cancel();
  Future<void> dispose();
}

/// Real capture via `record`'s in-memory PCM stream. Nothing touches disk: the
/// stream chunks are accumulated in memory and returned as raw PCM.
class RecordAudioGateway implements AudioCaptureGateway {
  RecordAudioGateway([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    _buffer.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: _kNumChannels,
      ),
    );
    _subscription = stream.listen(_buffer.add);
  }

  @override
  Future<Uint8List> stop() async {
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    return _buffer.takeBytes();
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _buffer.clear();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _recorder.dispose();
  }
}

/// Wrap raw s16 little-endian PCM in a 44-byte WAV/RIFF header so the backend
/// receives a self-describing `audio/wav` payload. No file is written.
Uint8List _wrapPcmAsWav(Uint8List pcm) {
  const bytesPerSample = _kBitsPerSample ~/ 8;
  final byteRate = _kSampleRate * _kNumChannels * bytesPerSample;
  final blockAlign = _kNumChannels * bytesPerSample;
  final dataSize = pcm.length;

  final header = BytesBuilder();
  void writeAscii(String value) => header.add(ascii.encode(value));
  void writeUint32(int value) => header.add([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
  void writeUint16(int value) =>
      header.add([value & 0xff, (value >> 8) & 0xff]);

  writeAscii('RIFF');
  writeUint32(36 + dataSize);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16); // PCM format chunk size
  writeUint16(1); // audio format = PCM
  writeUint16(_kNumChannels);
  writeUint32(_kSampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(_kBitsPerSample);
  writeAscii('data');
  writeUint32(dataSize);

  final headerBytes = header.toBytes();
  final wav = Uint8List(headerBytes.length + pcm.length);
  wav.setAll(0, headerBytes);
  wav.setAll(headerBytes.length, pcm);
  return wav;
}
