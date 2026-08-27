import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/sub_service_catalog_screen.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      home: child,
    );

void main() {
  group('ServiceCartController', () {
    test('adds, increments, decrements, and calculates totals correctly', () {
      final cart = ServiceCartController();
      const item1 = SubServiceItem(
        id: 'p1',
        categorySlug: 'plumbing',
        name: 'Tap Repair',
        description: 'Fix tap',
        priceMinor: 14900, // ₹149
        durationMinutes: 30,
      );
      const item2 = SubServiceItem(
        id: 'p2',
        categorySlug: 'plumbing',
        name: 'Flush Tank Fix',
        description: 'Fix cistern',
        priceMinor: 24900, // ₹249
        durationMinutes: 45,
      );

      expect(cart.isEmpty, isTrue);

      // Add item 1
      cart.add(item1);
      expect(cart.totalItemCount, 1);
      expect(cart.totalPriceMinor, 14900);
      expect(cart.gstMinor, 2682); // 14900 * 0.18 = 2682
      expect(cart.grandTotalMinor, 17582);

      // Add item 1 again (increment)
      cart.add(item1);
      expect(cart.totalItemCount, 2);
      expect(cart.getQuantity('p1'), 2);
      expect(cart.totalPriceMinor, 29800);

      // Add item 2
      cart.add(item2);
      expect(cart.totalItemCount, 3);
      expect(cart.summaryDescription, 'Tap Repair (x2), Flush Tank Fix (x1)');

      // Decrement item 1
      cart.decrement(item1);
      expect(cart.getQuantity('p1'), 1);

      // Decrement again removes item 1
      cart.decrement(item1);
      expect(cart.getQuantity('p1'), 0);
      expect(cart.totalItemCount, 1);
    });
  });

  group('SubServiceCatalogScreen', () {
    const testCategory = ServiceCategory(
      id: 'cat-plumbing',
      name: 'Plumbing',
      slug: 'plumbing',
      description: 'Pipe repairs and fixes',
      iconName: 'plumbing',
      isEmergency: false,
      pricing: ServiceCategoryPricing(amountMinor: 14900, currency: 'INR'),
      verifiedProCount: 3,
      onlineProCount: 2,
      rating: 4.9,
      reviewCount: 120,
    );

    testWidgets('renders sub-services and shows floating cart when items added',
        (tester) async {
      String? proceededDescription;
      int? proceededPrice;

      await tester.pumpWidget(
        host(
          SubServiceCatalogScreen(
            category: testCategory,
            onProceedToBooking: (cat, desc, price, loc) {
              proceededDescription = desc;
              proceededPrice = price;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Tap & Mixer Repair'), findsOneWidget);
      expect(find.text('Flush Tank & Jet Spray Fix'), findsOneWidget);
      expect(find.text('3 Verified Pros Nearby'), findsOneWidget);

      // Floating cart should be hidden initially
      expect(find.text('Book Now'), findsNothing);

      // Add "Tap & Mixer Repair"
      final addFinders = find.text('ADD');
      expect(addFinders, findsWidgets);
      await tester.tap(addFinders.first);
      await tester.pumpAndSettle();

      // Floating cart should now be visible!
      expect(find.text('Book Now'), findsOneWidget);
      expect(find.textContaining('1 item'), findsOneWidget);

      // Tap + to increment quantity
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('2 items'), findsOneWidget);

      // Tap Book Now
      await tester.tap(find.text('Book Now'));
      await tester.pumpAndSettle();

      expect(proceededDescription, 'Tap & Mixer Repair (x2)');
      expect(proceededPrice, 35164); // 29800 subtotal + 5364 GST
    });

    testWidgets('search query filters available sub-services', (tester) async {
      await tester.pumpWidget(
        host(
          const SubServiceCatalogScreen(category: testCategory),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tap & Mixer Repair'), findsOneWidget);
      expect(find.text('Flush Tank & Jet Spray Fix'), findsOneWidget);

      // Enter search query "flush"
      await tester.enterText(find.byType(TextField), 'flush');
      await tester.pumpAndSettle();

      expect(find.text('Flush Tank & Jet Spray Fix'), findsOneWidget);
      expect(find.text('Tap & Mixer Repair'), findsNothing);
    });
  });
}
