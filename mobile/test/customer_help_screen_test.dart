import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/support/complaint.dart';
import 'package:fixnow_mobile/features/support/customer_help_screen.dart';

class _FakeComplaintsRepo implements ComplaintsRepository {
  @override
  Future<List<Complaint>> listComplaints() async => [];

  @override
  Future<Complaint> getComplaint(String id) async => throw UnimplementedError();

  @override
  Future<Complaint> submitComplaint({
    String? bookingId,
    required String targetRole,
    String? targetId,
    required String category,
    required String description,
  }) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('renders Stitch Customer Help & Support screen elements correctly',
      (tester) async {
    final controller = ComplaintsController(_FakeComplaintsRepo());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: CustomerHelpScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and hero
    expect(find.text('Help & Knowledge Base'), findsOneWidget);
    expect(find.text('24/7 RESOLUTION PORTAL'), findsOneWidget);
    expect(find.text('Desk Online'), findsOneWidget);

    // Verify Emergency Hazard alert banner
    expect(find.text('Active Electrical or Gas Hazard?'), findsOneWidget);
    expect(find.text('Call 24/7 Safety Desk (Toll Free)'), findsOneWidget);

    // Verify Quick Resolution Hub
    expect(find.text('Quick Resolution Hub'), findsOneWidget);
    expect(find.text('File or Report Dispute'), findsOneWidget);
    expect(find.text('Track Tickets'), findsOneWidget);
    expect(find.text('Call Support'), findsOneWidget);
    expect(find.text('WhatsApp Desk'), findsOneWidget);

    // Verify FAQs
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.textContaining('FixNow 30-Day Rework Warranty'), findsOneWidget);
    expect(find.textContaining('Start PIN'), findsOneWidget);

    // Verify Contact Card & Callback
    expect(find.text('Still need assistance?'), findsOneWidget);
    expect(find.text('Chat with Trust Team'), findsOneWidget);
    final callbackBtn = find.text('Request Instant Callback');
    expect(callbackBtn, findsOneWidget);

    // Tap Request Instant Callback with ensureVisible
    await tester.ensureVisible(callbackBtn);
    await tester.pumpAndSettle();
    await tester.tap(callbackBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Callback request queued!'), findsOneWidget);

    // Test search filter
    final searchField = find.byType(TextField);
    await tester.ensureVisible(searchField);
    await tester.pumpAndSettle();
    await tester.enterText(searchField, 'Escrow');
    await tester.pumpAndSettle();
    expect(find.textContaining('How does FixNow Escrow protect my payment?'), findsOneWidget);
  });
}
