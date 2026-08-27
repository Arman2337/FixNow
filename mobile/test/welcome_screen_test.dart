import 'package:fixnow_mobile/auth/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: child,
  ),
);

void main() {
  Widget welcome() => WelcomeScreen(onGetStarted: () {}, onSignIn: () {});

  testWidgets('staggered entrance settles to show headline and both CTAs', (
    tester,
  ) async {
    await tester.pumpWidget(host(welcome()));
    // Advance past the longest stagger delay (~540ms) so the delayed tickers
    // start, then let every entrance animation finish.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Trusted help.'), findsOneWidget);
    expect(find.text('When you need it.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('reduce motion shows content on the first frame', (tester) async {
    await tester.pumpWidget(host(welcome(), reduceMotion: true));
    await tester.pump(); // a single frame — no settling

    // The masked headline and CTAs must be present immediately, not gated
    // behind motion that reduce-motion users never see complete.
    expect(find.text('Trusted help.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    // Flush the (motion-ignored) delay timers so teardown stays clean.
    await tester.pump(const Duration(milliseconds: 700));
  });
}
