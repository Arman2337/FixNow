import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ScaffoldMessengerState> _pumpHost(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      scaffoldMessengerKey: messengerKey,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Container()),
      ),
    ),
  );
  return messengerKey.currentState!;
}

void main() {
  testWidgets('success banner renders title, message, and burn-down', (
    tester,
  ) async {
    final messenger = await _pumpHost(tester);
    showFixBanner(
      messenger,
      tone: FixBannerTone.success,
      title: 'Visit booked',
      message: 'We are finding an eligible provider.',
    );
    await tester.pump();

    expect(find.text('Visit booked'), findsOneWidget);
    expect(find.text('We are finding an eligible provider.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1.0);
    expect(bar.color, AppColors.live);
  });

  testWidgets('info and danger tones render their own icons and colors', (
    tester,
  ) async {
    var messenger = await _pumpHost(tester);
    showFixBanner(messenger, message: 'Connecting…');
    await tester.pump();
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

    messenger = await _pumpHost(tester);
    showFixBanner(messenger, tone: FixBannerTone.danger, message: 'Offline.');
    await tester.pump();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, AppColors.danger);
  });

  testWidgets('banner passes its duration to the framework dismissal', (
    tester,
  ) async {
    final messenger = await _pumpHost(tester);
    showFixBanner(
      messenger,
      message: 'Temporary',
      duration: const Duration(seconds: 2),
    );
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 2));
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('action label fires the callback', (tester) async {
    final messenger = await _pumpHost(tester);
    var fired = false;
    showFixBanner(
      messenger,
      message: 'Navigating',
      actionLabel: 'DISMISS',
      onAction: () => fired = true,
    );
    await tester.pump();
    // Let the entrance animation finish so the tap lands on the action.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('DISMISS'));
    expect(fired, isTrue);
  });

  testWidgets('reduced motion omits the burn-down bar entirely', (
    tester,
  ) async {
    final messenger = await _pumpHost(tester, disableAnimations: true);
    showFixBanner(messenger, message: 'Calm banner');
    await tester.pump();

    expect(find.text('Calm banner'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
