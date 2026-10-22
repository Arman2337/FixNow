import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/guarantees/data/guarantee_repository.dart';
import 'package:fixnow_mobile/features/guarantees/ui/submit_claim_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClaimTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return ApiResponse(
      statusCode: 201,
      body: {
        'id': 'claim-1',
        'bookingId': 'booking-1',
        'customerId': 'customer-1',
        'status': 'PENDING',
        'description': 'Leaking pipe again',
        'createdAt': '2026-10-21T10:00:00Z',
        'updatedAt': '2026-10-21T10:00:00Z',
      },
    );
  }
}

void main() {
  testWidgets(
    'short claim is rejected inline before any request; valid claim submits',
    (tester) async {
      final transport = _ClaimTransport();
      await tester.pumpWidget(
        MaterialApp(
          home: SubmitClaimScreen(
            bookingId: 'booking-1',
            repository: GuaranteeRepository(
              transport,
              accessToken: () async => 'token',
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Leak pipe');
      await tester.tap(find.text('Submit Claim'));
      await tester.pump();
      expect(
        find.text('Describe the issue in at least 10 characters.'),
        findsOneWidget,
      );
      expect(transport.requests, isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        '  Leaking pipe again  ',
      );
      await tester.tap(find.text('Submit Claim'));
      await tester.pumpAndSettle();
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.body, {
        'bookingId': 'booking-1',
        'description': 'Leaking pipe again',
      });
    },
  );
}
