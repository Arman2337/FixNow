import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/ai/ai_diagnostic_screen.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';

void main() {
  testWidgets('renders FixAI Diagnostics header, mode tabs, and interactive viewfinder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AiDiagnosticScreen(
          category: ServiceCategory(
            id: 'cat-1',
            name: 'Plumbing',
            slug: 'plumbing',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FixAI Diagnostics'), findsOneWidget);
    expect(find.text('Scan Image'), findsOneWidget);
    expect(find.text('Record Audio'), findsOneWidget);
    expect(find.text('Text Prompt'), findsOneWidget);

    // Initial mode is camera
    expect(find.textContaining('CLASSIFIER'), findsOneWidget);

    // Switch to Record Audio
    await tester.tap(find.text('Record Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Record Audio'), findsOneWidget);

    // Switch to Text Prompt
    await tester.tap(find.text('Text Prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Text Prompt'), findsOneWidget);
  });

  testWidgets('triggers onBookSpecialist callback when CTA pressed', (tester) async {
    var booked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AiDiagnosticScreen(
          category: const ServiceCategory(
            id: 'cat-1',
            name: 'Plumbing',
            slug: 'plumbing',
          ),
          onBookSpecialist: () => booked = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.text('Auto-Book Specialist');
    await tester.scrollUntilVisible(cta, 200);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(booked, isTrue);
  });
}
