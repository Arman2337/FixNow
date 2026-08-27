import 'package:fixnow_mobile/design_system/fix_payment_checkout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );

void main() {
  group('FixPaymentCheckoutSheet', () {
    testWidgets('calculates subtotal, GST, and grand total correctly',
        (tester) async {
      await tester.pumpWidget(
        host(
          const FixPaymentCheckoutSheet(
            bookingId: 'book-123',
            baseAmountMinor: 49900, // ₹499
            sparePartsMinor: 10000, // ₹100
            proName: 'Arun Kumar',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subtotal = 599, GST = 107.82, Total = 706.82
      expect(find.text('Checkout & Pay'), findsOneWidget);
      expect(find.text('Base Service & Labour'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('Approved Spare Parts'), findsOneWidget);
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('GST (18% Goods & Services Tax)'), findsOneWidget);
      expect(find.text('₹107.82'), findsOneWidget);
      expect(find.text('₹706.82'), findsNWidgets(2)); // summary + bottom bar
    });

    testWidgets('selecting a tip dynamically updates the grand total',
        (tester) async {
      await tester.pumpWidget(
        host(
          const FixPaymentCheckoutSheet(
            bookingId: 'book-123',
            baseAmountMinor: 49900, // ₹499
            sparePartsMinor: 0,
            proName: 'Arun Kumar',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Base 499 + GST 89.82 = 588.82
      expect(find.text('₹588.82'), findsNWidgets(2));

      // Tap +₹50 tip
      await tester.tap(find.text('+₹50 ⭐'));
      await tester.pumpAndSettle();

      // 588.82 + 50 = 638.82
      expect(find.text('₹638.82'), findsNWidgets(2));
      expect(find.text('Technician Appreciation Tip'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
    });

    testWidgets('switching to Cash changes button label to Confirm Cash Pay',
        (tester) async {
      await tester.pumpWidget(
        host(
          const FixPaymentCheckoutSheet(
            bookingId: 'book-123',
            baseAmountMinor: 49900,
            proName: 'Arun Kumar',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pay ₹588.82'), findsOneWidget);

      // Scroll into view and select Cash on Delivery
      final cashFinder = find.text('Cash on Delivery (Pay to Pro)');
      await tester.ensureVisible(cashFinder);
      await tester.pumpAndSettle();
      await tester.tap(cashFinder);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Cash Pay'), findsOneWidget);
    });

    testWidgets('successful payment transitions to celebratory success modal',
        (tester) async {
      var processCalled = false;
      var doneCalled = false;

      await tester.pumpWidget(
        host(
          FixPaymentCheckoutSheet(
            bookingId: 'book-456',
            baseAmountMinor: 49900,
            proName: 'Vikram Singh',
            onProcessPayment: ({
              required paymentMethod,
              required totalMinor,
              required tipMinor,
            }) async {
              processCalled = true;
            },
            onDone: () {
              doneCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Pay
      await tester.tap(find.text('Pay ₹588.82'));
      await tester.pump(); // starts loading
      await tester.pump(const Duration(milliseconds: 1000)); // completes
      await tester.pumpAndSettle();

      expect(processCalled, isTrue);
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('TXN-BOOK-456'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done
      await tester.tap(find.text('Done'));
      expect(doneCalled, isTrue);
    });
  });
}
