import 'dart:typed_data';
import 'package:fixnow_mobile/design_system/fix_before_after_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: child),
);

final dummyBytes = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  group('FixBeforeAfterSlider', () {
    testWidgets('renders badges, fallback placeholders and handle', (
      tester,
    ) async {
      await tester.pumpWidget(host(const FixBeforeAfterSlider(height: 200)));
      await tester.pumpAndSettle();

      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('AFTER'), findsOneWidget);
      expect(find.byIcon(Icons.compare_arrows_rounded), findsOneWidget);
    });

    testWidgets('renders with image bytes and responds to horizontal drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FixBeforeAfterSlider(
            beforeBytes: dummyBytes,
            afterBytes: dummyBytes,
            height: 220,
            initialPosition: 0.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('AFTER'), findsOneWidget);

      // Perform horizontal drag
      final handleFinder = find.byIcon(Icons.compare_arrows_rounded);
      expect(handleFinder, findsOneWidget);

      await tester.drag(handleFinder, const Offset(-50, 0));
      await tester.pumpAndSettle();

      await tester.drag(handleFinder, const Offset(100, 0));
      await tester.pumpAndSettle();
    });
  });
}
