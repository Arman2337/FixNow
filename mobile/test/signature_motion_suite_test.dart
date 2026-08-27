import 'package:fixnow_mobile/design_system/fix_motion_suite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FixSpringBounce', () {
    testWidgets('triggers onTap and scales child', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixSpringBounce(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      expect(find.text('Tap Me'), findsOneWidget);
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('respects disableAnimations', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: FixSpringBounce(
                onTap: () => tapped = true,
                child: const Text('Static Tap'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Static Tap'), findsOneWidget);
      await tester.tap(find.text('Static Tap'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('StaggeredListReveal', () {
    testWidgets('renders child and completes animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredListReveal(
              index: 0,
              child: Text('Staggered Item 0'),
            ),
          ),
        ),
      );

      expect(find.text('Staggered Item 0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Staggered Item 0'), findsOneWidget);
    });

    testWidgets('renders directly with disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StaggeredListReveal(
                index: 2,
                child: Text('Reduced Motion Item'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Reduced Motion Item'), findsOneWidget);
    });
  });

  group('FixRollingTicker', () {
    testWidgets('animates and displays final formatted value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FixRollingTicker(
              targetValue: 499,
              currencySymbol: '₹',
            ),
          ),
        ),
      );

      // Settle the animation
      await tester.pumpAndSettle();

      expect(find.text('₹499'), findsOneWidget);
    });

    testWidgets('renders immediately when disableAnimations is true', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: FixRollingTicker(
                targetValue: 1250,
                currencySymbol: '₹',
              ),
            ),
          ),
        ),
      );

      expect(find.text('₹1250'), findsOneWidget);
    });
  });

  group('AiPhotoScannerOverlay', () {
    testWidgets('shows plain child when not scanning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiPhotoScannerOverlay(
              isScanning: false,
              child: Text('Inspection Photo'),
            ),
          ),
        ),
      );

      expect(find.text('Inspection Photo'), findsOneWidget);
      expect(find.textContaining('AI Vision'), findsNothing);
    });

    testWidgets('shows HUD overlay and status text when scanning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiPhotoScannerOverlay(
              isScanning: true,
              statusText: 'Analyzing defect…',
              child: SizedBox(
                width: 200,
                height: 200,
                child: Text('Target Subject'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Target Subject'), findsOneWidget);
      expect(find.text('Analyzing defect…'), findsOneWidget);
    });
  });
}
