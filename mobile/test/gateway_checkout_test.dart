import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/payments/gateway_checkout_repository.dart';
import 'package:fixnow_mobile/features/payments/group_service_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'group checkout requires confirming service before opening Razorpay',
    (tester) async {
      final api = _GatewayApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupServicePayment(
              repository: GatewayCheckoutRepository(
                api,
                Uri.parse('https://fixnow.example/api/v1/'),
                () async => 'access-token',
              ),
              groupId: 'group-1',
              amountMinor: 75000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹750.00'), findsOneWidget);
      await tester.tap(find.text('Pay with UPI'));
      await tester.pumpAndSettle();
      expect(api.checkout, isNull);
      await tester.tap(find.text('I received the service'));
      await tester.pumpAndSettle();

      expect(api.checkout?.path, 'payments/checkout/group-services/group-1');
      expect(api.checkout?.body, {'serviceReceived': true});
      expect(api.checkout?.bearerToken, 'access-token');
      expect(find.text('Open secure checkout'), findsOneWidget);
      expect(find.text('Payment confirmed'), findsNothing);
    },
  );

  test(
    'booking checkout uses the FixNow backend and a fragment capability',
    () async {
      final api = _GatewayApi();
      final repo = GatewayCheckoutRepository(
        api,
        Uri.parse('https://fixnow.example/api/v1/'),
        () async => 'access-token',
      );
      final uri = await repo.start('booking-1', group: false);
      expect(api.checkout?.path, 'payments/checkout/bookings/booking-1');
      expect(api.checkout?.body, isNull);
      expect(
        uri.toString(),
        'https://fixnow.example/api/v1/payments/checkout#test-capability',
      );
    },
  );
}

class _GatewayApi implements ApiTransport {
  ApiRequest? checkout;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    switch (request.path) {
      case 'payments/checkout/availability':
        return const ApiResponse(statusCode: 200, body: {'available': true});
      case 'payments/orders/group-services/group-1':
        return const ApiResponse(statusCode: 200, body: null);
      case 'payments/checkout/group-services/group-1':
      case 'payments/checkout/bookings/booking-1':
        checkout = request;
        return const ApiResponse(
          statusCode: 201,
          body: {'token': 'test-capability'},
        );
      default:
        throw StateError('Unexpected checkout API request');
    }
  }
}
