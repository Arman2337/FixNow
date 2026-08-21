import 'package:fixnow_mobile/features/support/complaint.dart';
import 'package:fixnow_mobile/features/support/complaint_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows authoritative support progress and case timestamps', (
    tester,
  ) async {
    final complaint = Complaint(
      id: 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
      submitterId: 'customer-1',
      targetRole: 'PROVIDER',
      category: 'Service quality',
      description: 'The repair needs a follow-up visit.',
      status: 'IN_REVIEW',
      createdAt: DateTime.utc(2026, 8, 20, 10, 30),
      updatedAt: DateTime.utc(2026, 8, 20, 11, 45),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ComplaintDetailScreen(
          complaintId: complaint.id,
          complaint: complaint,
        ),
      ),
    );

    expect(find.text('Support case #A1B2C3D4'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('Support is reviewing your report'), findsOneWidget);
    expect(find.textContaining('Created 20 Aug 2026'), findsOneWidget);
    expect(find.textContaining('Last updated 20 Aug 2026'), findsOneWidget);
  });
}
