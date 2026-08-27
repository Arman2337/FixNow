import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProblemAnalysis.fromJson', () {
    test('parses a full grounded analysis with a high confidence band', () {
      final analysis = ProblemAnalysis.fromJson(const <String, Object?>{
        'kind': 'analysis',
        'source': 'image_voice',
        'category': 'Plumbing',
        'subcategory': 'Pipe leak',
        'problemSummary': 'A pipe under the sink is leaking.',
        'urgency': 'high',
        'confidence': 0.92,
        'confidenceBand': 'high',
        'transcription': 'water is dripping under my sink',
        'serviceCategoryId': 'cat-123',
        'serviceName': 'Plumbing',
        'safetyNotice': 'Turn off the water supply if it is safe to do so.',
      });

      expect(analysis.isAnalysis, isTrue);
      expect(analysis.kind, ProblemAnalysisKind.analysis);
      expect(analysis.source, 'image_voice');
      expect(analysis.category, 'Plumbing');
      expect(analysis.subcategory, 'Pipe leak');
      expect(analysis.problemSummary, 'A pipe under the sink is leaking.');
      expect(analysis.urgency, ProblemUrgency.high);
      expect(analysis.confidence, 0.92);
      expect(analysis.confidenceBand, ProblemConfidenceBand.high);
      expect(analysis.transcription, 'water is dripping under my sink');
      expect(analysis.serviceCategoryId, 'cat-123');
      expect(analysis.serviceName, 'Plumbing');
      expect(analysis.safetyNotice, isNotNull);
      expect(analysis.isBookable, isTrue);
    });

    test('an image result omits transcription and may be ungrounded', () {
      final analysis = ProblemAnalysis.fromJson(const <String, Object?>{
        'kind': 'analysis',
        'source': 'image',
        'category': 'Other',
        'subcategory': 'Other',
        'problemSummary': 'Unclear from the photo.',
        'urgency': 'medium',
        'confidence': 0.4,
        'confidenceBand': 'low',
        'serviceCategoryId': null,
        'serviceName': null,
        'safetyNotice': null,
      });

      expect(analysis.source, 'image');
      expect(analysis.transcription, isNull);
      expect(analysis.serviceCategoryId, isNull);
      expect(analysis.serviceName, isNull);
      expect(analysis.safetyNotice, isNull);
      expect(analysis.isBookable, isFalse);
      expect(analysis.confidenceBand, ProblemConfidenceBand.low);
      expect(analysis.urgency, ProblemUrgency.medium);
    });

    test('maps the medium band and defaults an unknown band to low', () {
      expect(
        ProblemAnalysis.fromJson(_analysisWith(confidenceBand: 'medium'))
            .confidenceBand,
        ProblemConfidenceBand.medium,
      );
      // An unrecognized band must degrade to low so the UI falls back to
      // manual browsing rather than a confident auto-suggestion.
      expect(
        ProblemAnalysis.fromJson(_analysisWith(confidenceBand: 'exceptional'))
            .confidenceBand,
        ProblemConfidenceBand.low,
      );
    });

    test('defaults an unknown urgency to medium', () {
      expect(
        ProblemAnalysis.fromJson(_analysisWith(urgency: 'critical')).urgency,
        ProblemUrgency.medium,
      );
      expect(
        ProblemAnalysis.fromJson(_analysisWith(urgency: 'low')).urgency,
        ProblemUrgency.low,
      );
    });

    test('parses an unavailable result with its error code', () {
      final analysis = ProblemAnalysis.fromJson(const <String, Object?>{
        'kind': 'unavailable',
        'source': 'voice',
        'errorCode': 'AI_DISABLED',
      });

      expect(analysis.isAnalysis, isFalse);
      expect(analysis.kind, ProblemAnalysisKind.unavailable);
      expect(analysis.source, 'voice');
      expect(analysis.errorCode, 'AI_DISABLED');
      expect(analysis.isBookable, isFalse);
    });

    test('throws FormatException on an unknown kind', () {
      expect(
        () => ProblemAnalysis.fromJson(const <String, Object?>{'kind': 'mystery'}),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _analysisWith({String? urgency, String? confidenceBand}) => {
  'kind': 'analysis',
  'source': 'voice',
  'category': 'Electrical',
  'subcategory': 'Wiring',
  'problemSummary': 'Sparks from an outlet.',
  'urgency': urgency ?? 'high',
  'confidence': 0.7,
  'confidenceBand': confidenceBand ?? 'medium',
  'serviceCategoryId': 'cat-9',
  'serviceName': 'Electrical',
  'safetyNotice': null,
};
