import 'package:fixnow_mobile/design_system/fix_3d_flip_card.dart';
import 'package:fixnow_mobile/design_system/fix_3d_spatial_beacon.dart';
import 'package:fixnow_mobile/design_system/fix_jelly_squish_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('3D & Advanced Motion Widgets Test Suite', () {
    testWidgets('Fix3DFlipCard renders front and flips on tap', (tester) async {
      var flippedState = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Fix3DFlipCard(
              cardNumber: '4829 •••• •••• 9281',
              cardHolder: 'ALEXANDER REED',
              onFlipped: (isBack) => flippedState = isBack,
            ),
          ),
        ),
      );

      // Verify front elements
      expect(find.text('4829 •••• •••• 9281'), findsOneWidget);
      expect(find.text('ALEXANDER REED'), findsOneWidget);
      expect(find.text('CVV / CVC'), findsNothing);

      // Tap to flip in 3D
      await tester.tap(find.byType(Fix3DFlipCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(flippedState, isTrue);
      expect(find.text('CVV / CVC'), findsOneWidget);
      expect(find.text('742'), findsOneWidget);
      expect(find.text('FixNow 256-Bit Escrow Vault Protected'), findsOneWidget);
    });

    testWidgets('Fix3DSpatialBeacon renders beacon pin and labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Fix3DSpatialBeacon(
              label: 'Matching in your area',
              sublabel: 'Searching within 5 km radius…',
            ),
          ),
        ),
      );

      expect(find.text('Matching in your area'), findsOneWidget);
      expect(find.text('Searching within 5 km radius…'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('FixJellySquishButton triggers tap and animates spring', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixJellySquishButton(
              label: 'Instant Book',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Instant Book'), findsOneWidget);

      await tester.tap(find.byType(FixJellySquishButton));
      await tester.pump();
      expect(tapped, isTrue);

      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
