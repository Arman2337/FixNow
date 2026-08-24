import 'package:fixnow_mobile/api/api_client.dart';

class AiRecommendation {
  const AiRecommendation({required this.kind, this.categoryId, this.serviceName, this.reason, this.clarificationQuestion, this.safetyNotice});
  final String kind;
  final String? categoryId;
  final String? serviceName;
  final String? reason;
  final String? clarificationQuestion;
  final String? safetyNotice;

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    final recommendation = json['recommendation'] as Map<String, dynamic>?;
    return AiRecommendation(
      kind: json['kind'] as String? ?? 'UNAVAILABLE',
      categoryId: recommendation?['serviceCategoryId'] as String?,
      serviceName: recommendation?['serviceName'] as String?,
      reason: recommendation?['reason'] as String?,
      clarificationQuestion: json['clarificationQuestion'] as String?,
      safetyNotice: json['safetyNotice'] as String?,
    );
  }
}

class AiRecommendationRepository {
  const AiRecommendationRepository(this._api, this._accessToken);
  final ApiTransport _api;
  final Future<String?> Function() _accessToken;

  Future<AiRecommendation> recommend(String description, {String? context}) async {
    final response = await _api.send(ApiRequest(
      method: ApiMethod.post,
      path: 'ai/service-recommendation',
      bearerToken: await _accessToken(),
      body: {
        'description': description,
        'clarificationContext': ?context,
      },
    ));
    if (response.body is! Map<String, dynamic>) throw const ApiException(ApiFailureKind.invalidResponse, 'FixNow AI is unavailable.');
    return AiRecommendation.fromJson(response.body! as Map<String, dynamic>);
  }
}
