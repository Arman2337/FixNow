import 'package:fixnow_mobile/design_system/fix_journey_progress_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FixJourneyProgressLine renders all 5 stages and highlights current stage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FixJourneyProgressLine(currentStatus: 'EN_ROUTE'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('Matched'), findsOneWidget);
    expect(find.text('En Route'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Completed checks for Booked and Matched (2 check icons)
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('FixJourneyProgressLine callback triggers on step tap', (tester) async {
    int? tappedStep;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FixJourneyProgressLine(
            currentStatus: 'REQUESTED',
            onStepTapped: (index) => tappedStep = index,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    expect(tappedStep, 4);
  });
}
