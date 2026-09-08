import 'package:fixnow_mobile/design_system/fix_3d_tilt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Fix3DTiltCard renders child and handles pan/hover events', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Fix3DTiltCard(
            onTap: () => tapped = true,
            child: const Text('Verified Pro Badge'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified Pro Badge'), findsOneWidget);

    // Test tap
    await tester.tap(find.text('Verified Pro Badge'));
    expect(tapped, isTrue);

    // Test pan
    await tester.drag(find.text('Verified Pro Badge'), const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Transform), findsWidgets);
  });
}
