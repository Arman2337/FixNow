import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/ai/price_estimate_repository.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
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

const category = ServiceCategory(
  id: '11111111-2222-4333-8444-555555555555',
  name: 'Plumbing',
  slug: 'plumbing',
  description: 'Leaks and pipe repairs',
  iconName: 'plumbing',
  pricing: ServiceCategoryPricing(amountMinor: 49900, currency: 'INR'),
);

Widget host({
  required ApiTransport transport,
  PriceEstimateRepository? repository,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 2400,
          child: ServiceRequestScreen(
            category: category,
            controller: BookingController(
              BookingRepository(api: transport, accessToken: () async => null),
            ),
            estimateRepository: repository,
          ),
        ),
      ),
    );

void main() {
  testWidgets('observed history shows the band, typical value, and notice',
      (tester) async {
    final transport = FakeTransport(
      (request) => ApiResponse(statusCode: 200, body: {
        'kind': 'ESTIMATE',
        'serviceCategoryId': category.id,
        'currency': 'INR',
        'minAmountMinor': 44900,
        'maxAmountMinor': 54900,
        'typicalAmountMinor': 49900,
        'basis': 'OBSERVED',
        'sampleSize': 12,
        'explanation': 'Typical range across 12 completed FixNow bookings.',
        'advisoryNotice': 'Advisory only — final charge confirmed at booking.',
      }),
    );
    await tester.pumpWidget(
      host(transport: transport, repository: PriceEstimateRepository(transport)),
    );
    await tester.pumpIdle();

    expect(
      transport.requests.single.path,
      'ai/price-estimate?serviceCategoryId=${category.id}',
    );
    expect(find.text('₹449 – ₹549'), findsOneWidget);
    expect(find.textContaining('Typically ₹499'), findsOneWidget);
    expect(find.textContaining('Advisory only'), findsOneWidget);
    expect(find.text('Base price'), findsNothing);
  });

  testWidgets('published pricing shows the standard charge', (tester) async {
    final transport = FakeTransport(
      (request) => ApiResponse(statusCode: 200, body: {
        'kind': 'ESTIMATE',
        'serviceCategoryId': category.id,
        'currency': 'INR',
        'minAmountMinor': 49900,
        'maxAmountMinor': 49900,
        'typicalAmountMinor': 49900,
        'basis': 'PUBLISHED',
        'sampleSize': null,
        'explanation': 'FixNow publishes a standard price.',
        'advisoryNotice': 'Advisory only — final charge confirmed at booking.',
      }),
    );
    await tester.pumpWidget(
      host(transport: transport, repository: PriceEstimateRepository(transport)),
    );
    await tester.pumpIdle();

    expect(find.text('₹499'), findsOneWidget);
    expect(find.textContaining('standard price'), findsOneWidget);
    expect(find.textContaining('Advisory only'), findsOneWidget);
  });

  testWidgets('a fetch failure keeps the static manual card', (tester) async {
    final transport = FakeTransport(
      (request) => const ApiResponse(statusCode: 503, body: <Object?>{}),
    );
    await tester.pumpWidget(
      host(transport: transport, repository: PriceEstimateRepository(transport)),
    );
    await tester.pumpIdle();

    expect(find.text('Base price'), findsOneWidget);
    expect(find.text('₹499'), findsOneWidget);
  });

  testWidgets('without a repository the static card renders immediately',
      (tester) async {
    await tester.pumpWidget(host(transport: FakeTransport((request) => const ApiResponse(statusCode: 200, body: <Object?>[]))));
    await tester.pumpIdle();

    expect(find.text('Base price'), findsOneWidget);
    expect(find.textContaining('price-estimate'), findsNothing);
  });
}
