import 'package:fixnow_mobile/design_system/fix_sos_vortex_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FixSosVortexButton requires holding for full duration to trigger',
    (tester) async {
      bool triggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixSosVortexButton(
              holdDuration: const Duration(milliseconds: 400),
              onTriggered: () => triggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOS'), findsOneWidget);

      // Short tap (<400ms) -> should NOT trigger
      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();
      expect(triggered, isFalse);

      // Long press holding full duration
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('SOS')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(triggered, isTrue);
    },
  );
}
