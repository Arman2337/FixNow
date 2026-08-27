import 'package:fixnow_mobile/design_system/fix_price_breakdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

void main() {
  group('FixPriceBreakdownCard', () {
    testWidgets('calculates 18% GST and total correctly', (tester) async {
      // 49900 paise = ₹499.00
      // 18% GST = 8982 paise = ₹89.82
      // Total = 58882 paise = ₹588.82
      await tester.pumpWidget(
        host(
          const FixPriceBreakdownCard(
            amountMinor: 49900,
            currency: 'INR',
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standard Flat Rate'), findsOneWidget);
      expect(find.text('Estimated Total'), findsOneWidget);
      expect(find.text('₹588.82'), findsOneWidget);
      expect(find.text('Standard Service Labour'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('GST (18% Goods & Services Tax)'), findsOneWidget);
      expect(find.text('₹89.82'), findsOneWidget);
      expect(find.textContaining('Transparent Pricing Guarantee'), findsOneWidget);
    });

    testWidgets('collapses and expands on toggle tap', (tester) async {
      await tester.pumpWidget(
        host(
          const FixPriceBreakdownCard(
            amountMinor: 49900,
            currency: 'INR',
            initiallyExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Details collapsed initially
      expect(find.text('View Breakdown'), findsOneWidget);
      expect(find.text('Standard Service Labour'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('View Breakdown'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Details'), findsOneWidget);
      expect(find.text('Standard Service Labour'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);

      // Tap to collapse again
      await tester.tap(find.text('Hide Details'));
      await tester.pumpAndSettle();

      expect(find.text('View Breakdown'), findsOneWidget);
      expect(find.text('Standard Service Labour'), findsNothing);
    });

    testWidgets('displays price on request fallback when amount is 0',
        (tester) async {
      await tester.pumpWidget(
        host(
          const FixPriceBreakdownCard(
            amountMinor: 0,
            currency: 'INR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Price on request'), findsOneWidget);
      expect(find.text('Estimated Total'), findsNothing);
    });
  });
}
