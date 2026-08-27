import 'package:fixnow_mobile/api/api_client.dart';

/// FN-058 / FN-059: advisory multimodal problem classification, mirroring the
/// shared `problem-analysis.types.ts` contract. Assistive guidance only — it
/// never books, assigns a provider, or sets a price; the customer always
/// confirms a category before the booking flow. `serviceCategoryId` is a
/// best-effort grounding to the active catalog and is `null` when there is no
/// confident match, in which case the client falls back to manual selection.
enum ProblemAnalysisKind { analysis, unavailable }

enum ProblemUrgency { low, medium, high }

/// Derived server-side from `confidence`: high ≥ 0.85, medium 0.60–0.84,
/// low < 0.60. Drives the suggest / confirm / manual-fallback behaviour.
enum ProblemConfidenceBand { high, medium, low }

class ProblemAnalysis {
  const ProblemAnalysis.analysis({
    required this.source,
    required this.category,
    required this.subcategory,
    required this.problemSummary,
    required this.urgency,
    required this.confidence,
    required this.confidenceBand,
    required this.serviceCategoryId,
    required this.serviceName,
    required this.safetyNotice,
    this.transcription,
  }) : kind = ProblemAnalysisKind.analysis,
       errorCode = null;

  const ProblemAnalysis.unavailable({
    required this.source,
    required this.errorCode,
  }) : kind = ProblemAnalysisKind.unavailable,
       category = null,
       subcategory = null,
       problemSummary = null,
       urgency = null,
       confidence = null,
       confidenceBand = null,
       transcription = null,
       serviceCategoryId = null,
       serviceName = null,
       safetyNotice = null;

  final ProblemAnalysisKind kind;

  /// `image` | `voice` | `image_voice` — the modality behind this result.
  final String source;
  final String? category;
  final String? subcategory;
  final String? problemSummary;
  final ProblemUrgency? urgency;
  final double? confidence;
  final ProblemConfidenceBand? confidenceBand;

  /// Present for voice / combined results; absent (null) for image.
  final String? transcription;

  /// Active DB service-category id when grounded, else `null`.
  final String? serviceCategoryId;

  /// Server-derived catalog name when grounded, else `null`.
  final String? serviceName;

  /// Deterministic safety guidance (gas/fire/shock/flooding), else `null`.
  final String? safetyNotice;

  /// Stable failure code on an `unavailable` result, else `null`.
  final String? errorCode;

  bool get isAnalysis => kind == ProblemAnalysisKind.analysis;

  /// Grounded to a bookable catalog category the client can hand off.
  bool get isBookable => serviceCategoryId != null;

  static ProblemAnalysis fromJson(Map<String, Object?> json) {
    switch (json['kind']) {
      case 'analysis':
        return ProblemAnalysis.analysis(
          source: json['source']! as String,
          category: json['category']! as String,
          subcategory: json['subcategory']! as String,
          problemSummary: json['problemSummary']! as String,
          urgency: _urgencyFrom(json['urgency']),
          confidence: (json['confidence']! as num).toDouble(),
          confidenceBand: _bandFrom(json['confidenceBand']),
          transcription: json['transcription'] as String?,
          serviceCategoryId: json['serviceCategoryId'] as String?,
          serviceName: json['serviceName'] as String?,
          safetyNotice: json['safetyNotice'] as String?,
        );
      case 'unavailable':
        return ProblemAnalysis.unavailable(
          source: json['source']! as String,
          errorCode: json['errorCode'] as String?,
        );
      default:
        throw const FormatException('Unknown problem analysis kind');
    }
  }

  static ProblemUrgency _urgencyFrom(Object? value) {
    switch (value) {
      case 'high':
        return ProblemUrgency.high;
      case 'low':
        return ProblemUrgency.low;
      default:
        return ProblemUrgency.medium;
    }
  }

  // An unrecognized band degrades to `low`, which forces the safe manual
  // fallback rather than a confident auto-suggestion.
  static ProblemConfidenceBand _bandFrom(Object? value) {
    switch (value) {
      case 'high':
        return ProblemConfidenceBand.high;
      case 'medium':
        return ProblemConfidenceBand.medium;
      default:
        return ProblemConfidenceBand.low;
    }
  }
}

/// Uploads media to the governed problem-analysis endpoints and parses the
/// discriminated result. The app talks only to the FixNow backend with the
/// customer bearer token; it never contacts a model provider directly.
class ProblemAnalysisRepository {
  ProblemAnalysisRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  Future<ProblemAnalysis> analyzeImage({required MultipartFileData image}) =>
      _upload('ai/problem-analysis/image', files: [image]);

  Future<ProblemAnalysis> analyzeVoice({
    required MultipartFileData audio,
    String? languageHint,
  }) => _upload(
    'ai/problem-analysis/voice',
    files: [audio],
    languageHint: languageHint,
  );

  Future<ProblemAnalysis> analyzeCombined({
    required MultipartFileData image,
    required MultipartFileData audio,
    String? languageHint,
  }) => _upload(
    'ai/problem-analysis/combined',
    files: [image, audio],
    languageHint: languageHint,
  );

  Future<ProblemAnalysis> _upload(
    String path, {
    required List<MultipartFileData> files,
    String? languageHint,
  }) async {
    // Multipart upload lives on the concrete client, not the transport port.
    final client = _transport;
    if (client is! ApiClient) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Uploads require the HTTP client.',
      );
    }
    final token = await _accessToken?.call();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to analyze a problem.',
      );
    }
    final response = await client.uploadMultipart(
      path: path,
      bearerToken: token,
      files: files,
      fields: languageHint == null ? null : {'languageHint': languageHint},
    );
    // Endpoints answer 201; uploadMultipart already accepts any 2xx and mapped
    // non-2xx to an ApiException, so only the body shape remains to check.
    if (response.body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected problem analysis response.',
      );
    }
    return ProblemAnalysis.fromJson(response.body! as Map<String, Object?>);
  }
}
