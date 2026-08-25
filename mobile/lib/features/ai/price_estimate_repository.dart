import 'package:fixnow_mobile/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// FN-113: advisory price estimate for one service category, mirroring the
/// shared `price-estimate.types.ts` contract. Advisory only — it never
/// changes what a booking charges.
class PriceEstimate {
  const PriceEstimate._({
    required this.kind,
    this.minLabel,
    this.maxLabel,
    this.typicalLabel,
    this.sampleSize,
    this.explanation = '',
    this.notice = '',
  });

  const PriceEstimate.standard({
    required String amountLabel,
    required String explanation,
    required String notice,
  }) : this._(
          kind: PriceEstimateKind.published,
          typicalLabel: amountLabel,
          explanation: explanation,
          notice: notice,
        );

  const PriceEstimate.observed({
    required String minLabel,
    required String maxLabel,
    required String typicalLabel,
    required int sampleSize,
    required String explanation,
    required String notice,
  }) : this._(
          kind: PriceEstimateKind.observed,
          minLabel: minLabel,
          maxLabel: maxLabel,
          typicalLabel: typicalLabel,
          sampleSize: sampleSize,
          explanation: explanation,
          notice: notice,
        );

  const PriceEstimate.onRequest() : this._(kind: PriceEstimateKind.priceOnRequest);

  final PriceEstimateKind kind;
  final String? minLabel;
  final String? maxLabel;
  final String? typicalLabel;
  final int? sampleSize;
  final String explanation;
  final String notice;

  /// "₹449 – ₹549" for observed bands; a single label otherwise.
  String get rangeLabel =>
      kind == PriceEstimateKind.observed ? '$minLabel – $maxLabel' : (typicalLabel ?? '');

  static PriceEstimate fromJson(Map<String, Object?> json) {
    switch (json['kind']) {
      case 'ESTIMATE':
        final currency = json['currency']! as String;
        final symbol = currency == 'INR' ? '₹' : '$currency ';
        final typical = _label(json['typicalAmountMinor'], symbol);
        final sampleSize = json['sampleSize'] as int?;
        return sampleSize == null
            ? PriceEstimate.standard(
                amountLabel: typical,
                explanation: json['explanation']! as String,
                notice: json['advisoryNotice']! as String,
              )
            : PriceEstimate.observed(
                minLabel: _label(json['minAmountMinor'], symbol),
                maxLabel: _label(json['maxAmountMinor'], symbol),
                typicalLabel: typical,
                sampleSize: sampleSize,
                explanation: json['explanation']! as String,
                notice: json['advisoryNotice']! as String,
              );
      case 'PRICE_ON_REQUEST':
        return const PriceEstimate.onRequest();
      default:
        throw const FormatException('Unknown price estimate kind');
    }
  }

  /// Integer minor units (paise) to a rupee label: whole amounts stay whole.
  static String _label(Object? minor, String symbol) {
    final rupees = (minor! as num).toDouble() / 100;
    return rupees % 1 == 0
        ? '$symbol${rupees.toStringAsFixed(0)}'
        : '$symbol${rupees.toStringAsFixed(2)}';
  }
}

enum PriceEstimateKind { published, observed, priceOnRequest }

enum PriceEstimateState { loading, ready, onRequest, unavailable }

class PriceEstimateController extends ChangeNotifier {
  PriceEstimateController(this._repository);

  final PriceEstimateRepository _repository;

  PriceEstimateState state = PriceEstimateState.loading;
  PriceEstimate? estimate;

  Future<void> load(String serviceCategoryId) async {
    state = PriceEstimateState.loading;
    notifyListeners();
    try {
      estimate = await _repository.fetch(serviceCategoryId);
      state = estimate!.kind == PriceEstimateKind.priceOnRequest
          ? PriceEstimateState.onRequest
          : PriceEstimateState.ready;
    } on ApiException {
      // An unavailable estimate keeps the ordinary manual flow visible.
      state = PriceEstimateState.unavailable;
    } on FormatException {
      state = PriceEstimateState.unavailable;
    }
    notifyListeners();
  }
}

class PriceEstimateRepository {
  PriceEstimateRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  /// Category IDs are UUIDs, so the query string needs no escaping.
  Future<PriceEstimate> fetch(String serviceCategoryId) async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'ai/price-estimate?serviceCategoryId=$serviceCategoryId',
        bearerToken: await _accessToken?.call(),
      ),
    );
    if (response.statusCode != 200 || response.body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected price estimate response.',
      );
    }
    return PriceEstimate.fromJson(response.body as Map<String, Object?>);
  }
}
