import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/support/complaint.dart';
import 'package:fixnow_mobile/features/support/complaint_list_screen.dart';

class _FakeComplaintsRepo implements ComplaintsRepository {
  _FakeComplaintsRepo(this.items);
  final List<Complaint> items;

  @override
  Future<List<Complaint>> listComplaints() async => items;

  @override
  Future<Complaint> getComplaint(String id) async =>
      items.firstWhere((c) => c.id == id);

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
  testWidgets('renders Stitch Disputes & Cases Hub with active & resolved cases',
      (tester) async {
    final testComplaints = [
      Complaint(
        id: 'case-8821-active',
        submitterId: 'cust-1',
        targetRole: 'PROVIDER',
        category: 'AC Jet Servicing',
        description: 'Billing Discrepancy — Extra Gas Top-up Charged without Prior Consent',
        status: 'IN_REVIEW',
        createdAt: DateTime.utc(2026, 9, 14, 12, 10),
        updatedAt: DateTime.utc(2026, 9, 14, 12, 45),
      ),
      Complaint(
        id: 'case-7104-resolved',
        submitterId: 'cust-1',
        targetRole: 'PROVIDER',
        category: 'Tap repair minor dripping rework',
        description: 'Ceramic washer drip resolved at zero cost.',
        status: 'RESOLVED',
        createdAt: DateTime.utc(2026, 8, 22, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 22, 11, 30),
      ),
    ];

    final controller = ComplaintsController(_FakeComplaintsRepo(testComplaints));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ComplaintListScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Action
    expect(find.text('Disputes & Cases'), findsOneWidget);
    expect(find.text('Resolution Hub'), findsOneWidget);
    expect(find.text('+ New Case'), findsOneWidget);

    // Verify Escrow Guarantee Banner
    expect(find.text('FixNow Fair Dispute Guarantee'), findsOneWidget);
    expect(find.textContaining('Escrow funds locked'), findsOneWidget);

    // Verify Active Case Card
    expect(find.text('AC Jet Servicing'), findsOneWidget);
    expect(find.text('IN_REVIEW'), findsOneWidget);
    expect(find.text('Trust & Safety Officer'), findsOneWidget);
    expect(find.text('Live Lead'), findsOneWidget);
    expect(find.text('Resolution Milestones'), findsOneWidget);
    expect(find.text('Stage 3 of 4'), findsOneWidget);
    expect(find.text('Add Proof'), findsOneWidget);
    expect(find.text('Instant Callback'), findsOneWidget);

    // Tap Instant Callback
    final callbackBtn = find.text('Instant Callback');
    await tester.ensureVisible(callbackBtn);
    await tester.pumpAndSettle();
    await tester.tap(callbackBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Instant callback requested!'), findsOneWidget);

    // Scroll to Past Resolved Section
    await tester.scrollUntilVisible(find.text('Past Complaints History'), 200);
    expect(find.text('Past Complaints History'), findsOneWidget);
    expect(find.text('Tap repair minor dripping rework'), findsOneWidget);
    expect(find.text('Resolved'), findsWidgets);
  });
}
