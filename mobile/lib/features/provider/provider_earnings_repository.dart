import 'package:fixnow_mobile/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// FN-053: a provider's honest earnings ledger — records of completed payments
/// minus refunds. This is display-only: it never represents a payout, which no
/// provider supports yet (ADR-0016). Mirrors `PaymentsService.providerEarnings`.
class ProviderEarnings {
  const ProviderEarnings({
    required this.grossLabel,
    required this.refundedLabel,
    required this.netLabel,
    required this.paidOrderCount,
    required this.note,
  });

  final String grossLabel;
  final String refundedLabel;
  final String netLabel;
  final int paidOrderCount;
  final String note;

  static ProviderEarnings fromJson(Map<String, Object?> json) {
    // Earnings are INR-only (the backend sums amount_minor with no currency
    // dimension), so the rupee symbol is fixed rather than guessed.
    const symbol = '₹';
    return ProviderEarnings(
      grossLabel: _label(json['grossMinor'], symbol),
      refundedLabel: _label(json['refundedMinor'], symbol),
      netLabel: _label(json['netMinor'], symbol),
      paidOrderCount: (json['paidOrderCount']! as num).toInt(),
      note: json['note']! as String,
    );
  }

  /// Integer minor units (paise) to a rupee label: whole amounts stay whole.
  static String _label(Object? minor, String symbol) {
    final rupees = (minor! as num).toDouble() / 100;
    return rupees % 1 == 0
        ? '$symbol${rupees.toStringAsFixed(0)}'
        : '$symbol${rupees.toStringAsFixed(2)}';
  }
}

enum ProviderEarningsState { loading, ready, unavailable }

class ProviderEarningsController extends ChangeNotifier {
  ProviderEarningsController(this._repository);

  final ProviderEarningsRepository _repository;

  ProviderEarningsState state = ProviderEarningsState.loading;
  ProviderEarnings? earnings;

  Future<void> load() async {
    state = ProviderEarningsState.loading;
    notifyListeners();
    try {
      earnings = await _repository.fetch();
      state = ProviderEarningsState.ready;
    } on ApiException {
      state = ProviderEarningsState.unavailable;
    } on FormatException {
      state = ProviderEarningsState.unavailable;
    }
    notifyListeners();
  }
}

class ProviderEarningsRepository {
  ProviderEarningsRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  Future<ProviderEarnings> fetch() async {
    final response = await _transport.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'providers/me/earnings',
        bearerToken: await _accessToken?.call(),
      ),
    );
    if (response.statusCode != 200 || response.body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected earnings response.',
      );
    }
    return ProviderEarnings.fromJson(response.body as Map<String, Object?>);
  }
}
