import 'package:fixnow_mobile/design_system/fix_slide_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FixSlideToConfirm renders label and snaps back if drag threshold not met', (tester) async {
    bool confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FixSlideToConfirm(
            onConfirmed: () async => confirmed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SLIDE TO DISPATCH ➔'), findsOneWidget);

    // Small drag (<85%) -> should snap back and NOT confirm
    final handleFinder = find.byIcon(Icons.keyboard_double_arrow_right_rounded);
    await tester.drag(handleFinder, const Offset(50, 0));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(find.text('SLIDE TO DISPATCH ➔'), findsOneWidget);
  });

  testWidgets('FixSlideToConfirm triggers callback on full drag', (tester) async {
    bool confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: FixSlideToConfirm(
              onConfirmed: () async => confirmed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handleFinder = find.byIcon(Icons.keyboard_double_arrow_right_rounded);
    // Drag far enough across the 300px track
    await tester.drag(handleFinder, const Offset(280, 0));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('✓ DISPATCHED'), findsOneWidget);
  });
}
