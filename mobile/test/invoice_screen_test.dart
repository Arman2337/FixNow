import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_screen.dart';
import 'package:fixnow_mobile/features/payments/local_payment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_idle.dart';

/// Routes on request.path and mimics ApiClient's contract: non-2xx throws an
/// ApiException rather than returning a response (the invoice repository relies
/// on that for the order call).
class FakeTransport implements ApiTransport {
  FakeTransport(this.respond);

  final ApiResponse Function(ApiRequest request) respond;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

Widget host(ApiTransport transport, String bookingId) => MaterialApp(
  home: InvoiceScreen(
    repository: InvoiceRepository(transport, accessToken: () async => 'token'),
    bookingId: bookingId,
  ),
);

/// FN-118: the invoice screen with the dev-only local pay repository wired and
/// the bypass gate set explicitly (never reads the ambient build config).
Widget hostWithLocalPay(
  ApiTransport transport,
  String bookingId, {
  required bool bypassEnabled,
}) => MaterialApp(
  home: InvoiceScreen(
    repository: InvoiceRepository(transport, accessToken: () async => 'token'),
    localPaymentRepository: LocalPaymentRepository(
      transport,
      accessToken: () async => 'token',
    ),
    localPaymentBypassEnabled: bypassEnabled,
    bookingId: bookingId,
  ),
);

void main() {
  testWidgets('a paid booking shows the real invoice', (tester) async {
    final transport = FakeTransport((request) {
      if (request.path == 'payments/orders/booking/booking-1') {
        return ApiResponse(
          statusCode: 200,
          body: {
            'id': 'order-1',
            'bookingId': 'booking-1',
            'amountMinor': 150000,
            'currency': 'INR',
            'status': 'PAID',
            'gatewayOrderId': 'gw_1',
            'createdAt': '2026-08-20T10:00:00.000Z',
          },
        );
      }
      return ApiResponse(
        statusCode: 200,
        body: {
          'invoiceNumber': 'INV-2026-0007',
          'issuedAt': '2026-08-20T10:30:00.000Z',
          'amountMinor': 150000,
          'currency': 'INR',
          'status': 'PAID',
        },
      );
    });
    await tester.pumpWidget(host(transport, 'booking-1'));
    await tester.pumpIdle();

    // Walks order → invoice, in order.
    expect(transport.requests.map((r) => r.path).toList(), [
      'payments/orders/booking/booking-1',
      'payments/invoices/order-1',
    ]);
    expect(find.text('₹1500'), findsOneWidget); // amount paid
    expect(find.text('PAID'), findsOneWidget); // status row
    expect(find.text('INV-2026-0007'), findsNWidgets(2)); // header + details
  });

  testWidgets('an unpaid booking reports no invoice yet, without fetching one', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => ApiResponse(
        statusCode: 200,
        body: {
          'id': 'order-2',
          'bookingId': 'booking-2',
          'amountMinor': 150000,
          'currency': 'INR',
          'status': 'CREATED',
          'gatewayOrderId': 'gw_2',
          'createdAt': '2026-08-20T10:00:00.000Z',
        },
      ),
    );
    await tester.pumpWidget(host(transport, 'booking-2'));
    await tester.pumpIdle();

    expect(transport.requests.length, 1); // never asked for an invoice
    expect(find.text('No invoice yet'), findsOneWidget);
  });

  testWidgets('a booking with no payment order reports no invoice yet', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => const ApiResponse(statusCode: 200, body: null),
    );
    await tester.pumpWidget(host(transport, 'booking-3'));
    await tester.pumpIdle();

    expect(transport.requests.length, 1);
    expect(find.text('No invoice yet'), findsOneWidget);
  });

  testWidgets('a transport failure shows an honest retry state', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => throw const ApiException(
        ApiFailureKind.server,
        'The service is temporarily unavailable.',
        statusCode: 503,
      ),
    );
    await tester.pumpWidget(host(transport, 'booking-4'));
    await tester.pumpIdle();

    expect(find.text('Invoice unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('local bypass completes payment and reveals the invoice', (
    tester,
  ) async {
    // Stateful fake: the booking order reads CREATED until the verify call
    // flips it to PAID, mirroring the backend markPaid transition.
    var paid = false;
    final transport = FakeTransport((request) {
      switch (request.path) {
        case 'payments/orders/booking/booking-9':
          return ApiResponse(
            statusCode: 200,
            body: {
              'id': 'order-9',
              'bookingId': 'booking-9',
              'amountMinor': 150000,
              'currency': 'INR',
              'status': paid ? 'PAID' : 'CREATED',
              'gatewayOrderId': 'order_fake_9',
              'createdAt': '2026-08-27T10:00:00.000Z',
            },
          );
        case 'payments/orders':
          return const ApiResponse(
            statusCode: 201,
            body: {
              'id': 'order-9',
              'bookingId': 'booking-9',
              'amountMinor': 150000,
              'currency': 'INR',
              'status': 'CREATED',
              'gatewayOrderId': 'order_fake_9',
              'createdAt': '2026-08-27T10:00:00.000Z',
            },
          );
        case 'payments/orders/verify':
          paid = true;
          return const ApiResponse(
            statusCode: 200,
            body: {
              'id': 'order-9',
              'bookingId': 'booking-9',
              'amountMinor': 150000,
              'currency': 'INR',
              'status': 'PAID',
              'gatewayOrderId': 'order_fake_9',
              'createdAt': '2026-08-27T10:00:00.000Z',
            },
          );
        default: // payments/invoices/order-9
          return const ApiResponse(
            statusCode: 200,
            body: {
              'invoiceNumber': 'INV-2026-0009',
              'issuedAt': '2026-08-27T10:30:00.000Z',
              'amountMinor': 150000,
              'currency': 'INR',
              'status': 'PAID',
            },
          );
      }
    });

    await tester.pumpWidget(
      hostWithLocalPay(transport, 'booking-9', bypassEnabled: true),
    );
    await tester.pumpIdle();

    expect(find.text('No invoice yet'), findsOneWidget);
    expect(find.text('Complete payment (local)'), findsOneWidget);

    await tester.tap(find.text('Complete payment (local)'));
    await tester.pumpIdle();

    // Order created, verified with the fake signature, then order re-read + invoice.
    expect(transport.requests.map((r) => r.path).toList(), [
      'payments/orders/booking/booking-9', // initial load → pending
      'payments/orders', // create
      'payments/orders/verify', // verify
      'payments/orders/booking/booking-9', // reload → now PAID
      'payments/invoices/order-9', // invoice
    ]);
    expect(
      transport.requests[2].body?['razorpaySignature'],
      'fake-order_fake_9:pay_local_order_fake_9',
    );
    expect(find.text('No invoice yet'), findsNothing);
    expect(find.text('INV-2026-0009'), findsNWidgets(2)); // header + details
    expect(find.text('₹1500'), findsOneWidget);
  });

  testWidgets('without the local bypass the pending state offers no pay affordance', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => const ApiResponse(statusCode: 200, body: null),
    );
    await tester.pumpWidget(
      hostWithLocalPay(transport, 'booking-10', bypassEnabled: false),
    );
    await tester.pumpIdle();

    expect(find.text('No invoice yet'), findsOneWidget);
    expect(find.text('Complete payment (local)'), findsNothing);
  });
}
