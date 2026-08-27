import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/payments/local_payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements ApiTransport {
  _FakeTransport(this._respond);

  final ApiResponse Function(ApiRequest request) _respond;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return _respond(request);
  }
}

void main() {
  test('pay creates an order then verifies it with the fake signature', () async {
    final transport = _FakeTransport((request) {
      if (request.path == 'payments/orders') {
        return const ApiResponse(
          statusCode: 201,
          body: {
            'id': 'order-1',
            'bookingId': 'booking-1',
            'amountMinor': 150000,
            'currency': 'INR',
            'status': 'CREATED',
            'gatewayOrderId': 'order_fake_00000000000001',
            'createdAt': '2026-08-27T10:00:00.000Z',
          },
        );
      }
      return const ApiResponse(statusCode: 200, body: {'status': 'PAID'});
    });

    await LocalPaymentRepository(
      transport,
      accessToken: () async => 'token',
    ).pay('booking-1');

    expect(transport.requests.map((r) => r.path).toList(), [
      'payments/orders',
      'payments/orders/verify',
    ]);

    final create = transport.requests[0];
    expect(create.method, ApiMethod.post);
    expect(create.body, {'bookingId': 'booking-1'});
    expect(create.bearerToken, 'token');

    final verify = transport.requests[1];
    expect(verify.method, ApiMethod.post);
    expect(verify.body, {
      'orderId': 'order-1',
      'razorpayPaymentId': 'pay_local_order_fake_00000000000001',
      'razorpaySignature':
          'fake-order_fake_00000000000001:pay_local_order_fake_00000000000001',
    });
  });

  test('pay throws when the order response is not a map', () async {
    final transport = _FakeTransport(
      (_) => const ApiResponse(statusCode: 200, body: null),
    );
    await expectLater(
      LocalPaymentRepository(transport).pay('booking-1'),
      throwsA(isA<ApiException>()),
    );
    // Never reached the verify call.
    expect(transport.requests.length, 1);
  });
}
