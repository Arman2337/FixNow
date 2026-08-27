import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('MatchRadarView', () {
    testWidgets('plays staged copy and finishes via skip', (tester) async {
      var finished = false;
      await tester.pumpWidget(
        host(
          MatchRadarView(
            categoryName: 'Plumbing',
            onFinished: () => finished = true,
          ),
        ),
      );

      expect(find.text('Sharing your request…'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(finished, isTrue);
    });

    testWidgets('advances through all stages without interaction',
        (tester) async {
      var finished = false;
      await tester.pumpWidget(
        host(MatchRadarView(onFinished: () => finished = true)),
      );

      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(find.textContaining('accepts.'), findsNothing); // view is gone
    });
  });

  group('FlipOtpDigits', () {
    testWidgets('renders every digit of the code', (tester) async {
      await tester.pumpWidget(host(const FixOtpDisplay(otp: '736251')));
      await tester.pumpAndSettle();

      for (final digit in ['7', '3', '6', '2', '5', '1']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('reduce motion renders digits statically', (tester) async {
      await tester.pumpWidget(
        host(const FixOtpDisplay(otp: '736251'), reduceMotion: true),
      );
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('HoldToConfirmButton', () {
    testWidgets('fires only when the hold completes', (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(
        host(
          HoldToConfirmButton(
            label: 'Hold to send emergency alert',
            onConfirmed: () => confirmed++,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(HoldToConfirmButton));

      // Abandoned hold: past the recognizer deadline, short fill, release.
      final gesture = await tester.startGesture(center);
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(confirmed, 0);

      // Full hold: deadline + full 1600ms ring, advanced in 100ms steps.
      final gesture2 = await tester.startGesture(center);
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture2.up();
      await tester.pump();
      expect(confirmed, 1);
    });

    testWidgets('semantic tap path confirms instantly (accessibility)',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var confirmed = 0;
      await tester.pumpWidget(
        host(
          HoldToConfirmButton(
            label: 'Hold to send emergency alert',
            onConfirmed: () => confirmed++,
          ),
        ),
      );

      // Fire the semantic action itself — a pointer tap would miss the
      // Semantics.onTap path this test exists to cover.
      final node = tester.getSemantics(find.bySemanticsLabel(
        RegExp('^Hold to send emergency alert'),
      ));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(confirmed, 1);
      semantics.dispose();
    });
  });

  group('statusTemperatureColor', () {
    test('warms toward gold across the lifecycle and mutes on cancel', () {
      expect(statusTemperatureColor('REQUESTED'), AppColors.primary);
      expect(statusTemperatureColor('EN_ROUTE'), AppColors.success);
      expect(statusTemperatureColor('IN_PROGRESS'), AppColors.warning);
      expect(statusTemperatureColor('COMPLETED'), AppColors.rating);
      expect(
        statusTemperatureColor('CANCELLED'),
        AppColors.textSecondary,
      );
    });
  });
}
