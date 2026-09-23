import 'package:fixnow_mobile/design_system/fix_star_rating_burst.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FixStarRatingBurst renders 5 stars and handles selection', (
    tester,
  ) async {
    int currentRating = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FixStarRatingBurst(
            initialRating: 4,
            onRatingChanged: (r) => currentRating = r,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FixStarRatingBurst), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('Very Good Service!'), findsOneWidget);

    // Tap star 5 to trigger 5-star sparkle burst
    await tester.tap(find.byIcon(Icons.star_rounded).last);
    await tester.pump();

    expect(currentRating, 5);
    expect(find.text('Exceptional 5-Star Service!'), findsOneWidget);

    // Pump through sparkle animation
    await tester.pump(const Duration(milliseconds: 800));
  });
}
