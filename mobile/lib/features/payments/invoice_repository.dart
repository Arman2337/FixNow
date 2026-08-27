import 'package:fixnow_mobile/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// FN-053: the customer-visible invoice generated when a booking's payment was
/// completed. Mirrors `PaymentsService.getInvoice`. An invoice exists only for
/// a PAID payment order; until then the screen reports "not available yet"
/// rather than inventing one.
class Invoice {
  const Invoice({
    required this.invoiceNumber,
    required this.issuedAt,
    required this.amountLabel,
    required this.statusLabel,
  });

  final String invoiceNumber;
  final DateTime issuedAt;
  final String amountLabel;
  final String statusLabel;

  static Invoice fromJson(Map<String, Object?> json) {
    final currency = json['currency']! as String;
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return Invoice(
      invoiceNumber: json['invoiceNumber']! as String,
      issuedAt: DateTime.parse(json['issuedAt']! as String),
      amountLabel: _label(json['amountMinor'], symbol),
      statusLabel: json['status']! as String,
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

enum InvoiceState { loading, ready, pending, unavailable }

class InvoiceController extends ChangeNotifier {
  InvoiceController(this._repository, this._bookingId);

  final InvoiceRepository _repository;
  final String _bookingId;

  InvoiceState state = InvoiceState.loading;
  Invoice? invoice;

  Future<void> load() async {
    state = InvoiceState.loading;
    notifyListeners();
    try {
      invoice = await _repository.fetch(_bookingId);
      state = invoice == null ? InvoiceState.pending : InvoiceState.ready;
    } on ApiException {
      state = InvoiceState.unavailable;
    } on FormatException {
      state = InvoiceState.unavailable;
    }
    notifyListeners();
  }
}

class InvoiceRepository {
  InvoiceRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  /// Walks booking → payment order → invoice. Returns null (rather than
  /// throwing) whenever no invoice exists yet: no order, an unpaid order, or a
  /// paid order whose invoice is not materialised. Genuine transport failures
  /// still throw so the screen can offer a retry.
  Future<Invoice?> fetch(String bookingId) async {
    final token = await _accessToken?.call();
    final orderResponse = await _transport.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'payments/orders/booking/$bookingId',
        bearerToken: token,
      ),
    );
    final orderBody = orderResponse.body;
    if (orderBody == null) return null; // no payment order created yet
    if (orderBody is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected payment order response.',
      );
    }
    if (orderBody['status'] != 'PAID') return null; // payment not completed
    final orderId = orderBody['id']! as String;

    try {
      final invoiceResponse = await _transport.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'payments/invoices/$orderId',
          bearerToken: token,
        ),
      );
      if (invoiceResponse.statusCode != 200 ||
          invoiceResponse.body is! Map<String, Object?>) {
        throw const ApiException(
          ApiFailureKind.invalidResponse,
          'Unexpected invoice response.',
        );
      }
      return Invoice.fromJson(invoiceResponse.body as Map<String, Object?>);
    } on ApiException catch (error) {
      // 409 (invoices exist only for paid payments) is a defensive guard given
      // we already checked PAID; a 404 order-race is likewise "not yet".
      if (error.statusCode == 409 || error.statusCode == 404) return null;
      rethrow;
    }
  }
}
