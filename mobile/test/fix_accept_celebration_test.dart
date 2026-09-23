import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_accept_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('renders the acceptance banner copy', (tester) async {
    await tester.pumpWidget(
      host(
        const FixAcceptCelebration(serviceName: 'Plumbing', onDismiss: _noop),
      ),
    );
    await tester.pump();

    expect(find.text('Provider accepted!'), findsOneWidget);
    expect(find.textContaining('Plumbing pro is on it'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('tap anywhere dismisses', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(FixAcceptCelebration(onDismiss: () => dismissed = true)),
    );
    await tester.pump();

    await tester.tap(find.byType(FixAcceptCelebration));
    expect(dismissed, isTrue);
  });

  testWidgets('auto-dismisses after the celebrate beat', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(FixAcceptCelebration(onDismiss: () => dismissed = true)),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2300));
    expect(dismissed, isTrue);
  });

  testWidgets('reduced motion renders a static banner with no timer', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(
        FixAcceptCelebration(onDismiss: () => dismissed = true),
        disableAnimations: true,
      ),
    );
    // Must settle with no pending timers or looping animations.
    await tester.pumpAndSettle();

    expect(find.text('Provider accepted!'), findsOneWidget);
    expect(
      dismissed,
      isFalse,
      reason: 'static banner dismisses on tap only, never auto-dismisses',
    );
    await tester.tap(find.text('Provider accepted!'));
    expect(dismissed, isTrue);
  });
}

void _noop() {}
