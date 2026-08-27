import 'package:fixnow_mobile/api/api_client.dart';

/// FN-118: dev-only local checkout. Creates a booking's payment order and
/// verifies it against the deterministic fake gateway (ADR-0016) using the
/// gateway's own signature format, so a local build reaches a PAID order and
/// its invoice without any live credentials or card data. Gated by
/// `LocalPaymentConfig`; the backend `markPaid` transition remains the sole
/// authority on whether a payment succeeded — this never asserts success.
class LocalPaymentRepository {
  LocalPaymentRepository(
    this._transport, {
    Future<String?> Function()? accessToken,
  }) : _accessToken = accessToken;

  final ApiTransport _transport;
  final Future<String?> Function()? _accessToken;

  /// Drives create-order → verify for [bookingId]. Throws [ApiException] on any
  /// transport or validation failure so the caller can surface it honestly.
  /// The amount is derived server-side from the booking; the client only names
  /// the booking and never sends money.
  Future<void> pay(String bookingId) async {
    final token = await _accessToken?.call();
    final order = _order(
      await _transport.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'payments/orders',
          bearerToken: token,
          body: {'bookingId': bookingId},
        ),
      ),
    );
    final orderId = order['id']! as String;
    final gatewayOrderId = order['gatewayOrderId']! as String;
    // The fake gateway accepts exactly `fake-<gatewayOrderId>:<paymentId>`
    // (see backend/src/payments/payment-gateway.ts).
    final paymentId = 'pay_local_$gatewayOrderId';
    await _transport.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'payments/orders/verify',
        bearerToken: token,
        body: {
          'orderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': 'fake-$gatewayOrderId:$paymentId',
        },
      ),
    );
  }

  Map<String, Object?> _order(ApiResponse response) {
    final body = response.body;
    if (body is! Map<String, Object?>) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Unexpected payment order response.',
      );
    }
    return body;
  }
}
