import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_idle.dart';

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

Widget host(ApiTransport transport) => MaterialApp(
  home: ProviderEarningsScreen(
    repository: ProviderEarningsRepository(
      transport,
      accessToken: () async => 'token',
    ),
  ),
);

void main() {
  testWidgets('shows net, gross, refunded, count and the payout note', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => ApiResponse(
        statusCode: 200,
        body: {
          'grossMinor': 500000,
          'refundedMinor': 50000,
          'netMinor': 450000,
          'paidOrderCount': 9,
          'note':
              'Records of completed payments. Payouts are not available yet.',
        },
      ),
    );
    await tester.pumpWidget(host(transport));
    await tester.pumpIdle();

    expect(transport.requests.single.path, 'providers/me/earnings');
    expect(find.text('₹4500'), findsNWidgets(2));
    expect(find.text('₹5000'), findsNWidgets(2));
    expect(find.text('₹500'), findsNWidgets(2));
    expect(find.textContaining('9 completed payments'), findsOneWidget);
    expect(
      find.textContaining('Payouts are not available yet'),
      findsOneWidget,
    );
    expect(find.text('Daily Auto-Credit'), findsNothing);
    expect(find.text('Direct to Bank'), findsNothing);
    expect(find.text('Net Settled'), findsNothing);
    expect(find.text('Guaranteed'), findsNothing);
  });

  testWidgets('a single completed payment reads in the singular', (
    tester,
  ) async {
    final transport = FakeTransport(
      (request) => ApiResponse(
        statusCode: 200,
        body: {
          'grossMinor': 60000,
          'refundedMinor': 10100,
          'netMinor': 49900,
          'paidOrderCount': 1,
          'note':
              'Records of completed payments. Payouts are not available yet.',
        },
      ),
    );
    await tester.pumpWidget(host(transport));
    await tester.pumpIdle();

    expect(find.textContaining('1 completed payment.'), findsOneWidget);
    expect(find.text('₹499'), findsNWidgets(2));
  });

  testWidgets('a fetch failure shows an honest retry state', (tester) async {
    final transport = FakeTransport(
      (request) => const ApiResponse(statusCode: 503, body: <Object?>{}),
    );
    await tester.pumpWidget(host(transport));
    await tester.pumpIdle();

    expect(find.text('Earnings unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
