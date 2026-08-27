import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the multipart call the repository makes and returns a canned
/// response, without any real network. Multipart lives on the concrete
/// [ApiClient], so the fake extends it and overrides the one method used.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(this._response)
    : super(baseUri: Uri.parse('http://localhost/api/v1/'));

  final ApiResponse _response;

  String? path;
  String? bearerToken;
  List<MultipartFileData>? files;
  Map<String, String>? fields;

  @override
  Future<ApiResponse> uploadMultipart({
    required String path,
    required String bearerToken,
    required List<MultipartFileData> files,
    Map<String, String>? fields,
  }) async {
    this.path = path;
    this.bearerToken = bearerToken;
    this.files = files;
    this.fields = fields;
    return _response;
  }
}

class _NotAClient implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: null);
}

MultipartFileData _part(String field) => MultipartFileData(
  fieldName: field,
  fileName: '$field.bin',
  contentType: 'application/octet-stream',
  bytes: const [0, 1, 2],
);

const _analysisBody = <String, Object?>{
  'kind': 'analysis',
  'source': 'image_voice',
  'category': 'Plumbing',
  'subcategory': 'Leak',
  'problemSummary': 'A leak under the sink.',
  'urgency': 'high',
  'confidence': 0.9,
  'confidenceBand': 'high',
  'serviceCategoryId': 'cat-1',
  'serviceName': 'Plumbing',
  'safetyNotice': null,
};

void main() {
  test('combined upload posts to the combined path with token and hint',
      () async {
    final client = _FakeApiClient(
      const ApiResponse(statusCode: 201, body: _analysisBody),
    );
    final repository = ProblemAnalysisRepository(
      client,
      accessToken: () async => 'token-abc',
    );

    final analysis = await repository.analyzeCombined(
      image: _part('image'),
      audio: _part('audio'),
      languageHint: 'gu',
    );

    expect(client.path, 'ai/problem-analysis/combined');
    expect(client.bearerToken, 'token-abc');
    expect(client.files, hasLength(2));
    expect(client.fields, {'languageHint': 'gu'});
    expect(analysis.isAnalysis, isTrue);
    expect(analysis.serviceCategoryId, 'cat-1');
  });

  test('a null language hint omits the fields map', () async {
    final client = _FakeApiClient(
      const ApiResponse(statusCode: 201, body: _analysisBody),
    );
    final repository = ProblemAnalysisRepository(
      client,
      accessToken: () async => 'token',
    );

    await repository.analyzeImage(image: _part('image'));

    expect(client.path, 'ai/problem-analysis/image');
    expect(client.fields, isNull);
  });

  test('accepts a 201 unavailable body', () async {
    final client = _FakeApiClient(
      const ApiResponse(statusCode: 201, body: <String, Object?>{
        'kind': 'unavailable',
        'source': 'voice',
        'errorCode': 'AI_DISABLED',
      }),
    );
    final repository = ProblemAnalysisRepository(
      client,
      accessToken: () async => 'token',
    );

    final analysis = await repository.analyzeVoice(audio: _part('audio'));

    expect(analysis.isAnalysis, isFalse);
    expect(analysis.errorCode, 'AI_DISABLED');
  });

  test('a missing token fails as unauthorized before uploading', () async {
    final client = _FakeApiClient(
      const ApiResponse(statusCode: 201, body: _analysisBody),
    );
    final repository = ProblemAnalysisRepository(
      client,
      accessToken: () async => null,
    );

    await expectLater(
      repository.analyzeImage(image: _part('image')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.unauthorized,
        ),
      ),
    );
    expect(client.path, isNull); // the upload was never attempted
  });

  test('a non-map body is rejected as an invalid response', () async {
    final client = _FakeApiClient(
      const ApiResponse(statusCode: 201, body: <Object?>[]),
    );
    final repository = ProblemAnalysisRepository(
      client,
      accessToken: () async => 'token',
    );

    await expectLater(
      repository.analyzeImage(image: _part('image')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('a transport that is not an ApiClient is rejected', () async {
    final repository = ProblemAnalysisRepository(
      _NotAClient(),
      accessToken: () async => 'token',
    );

    await expectLater(
      repository.analyzeImage(image: _part('image')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
