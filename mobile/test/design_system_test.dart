import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme exposes the approved semantic colors', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.colorScheme.surface, AppColors.surfacePrimary);
    expect(theme.scaffoldBackgroundColor, AppColors.backgroundPrimary);
    expect(theme.textSelectionTheme.cursorColor, AppColors.primary);
    expect(theme.textSelectionTheme.selectionColor, AppColors.primarySoft);
    expect(AppColors.emergency, AppColors.danger);
    expect(AppColors.rating, isNot(AppColors.primary));
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.container, const Duration(milliseconds: 300));
    expect(
      _contrastRatio(AppColors.textPrimary, AppColors.backgroundPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.textOnLightPrimary, AppColors.surfacePrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.onPrimary, AppColors.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.textOnLightPrimary, AppColors.surfacePrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        AppColors.textOnLightSecondary,
        AppColors.surfaceSecondary,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        AppColors.textOnDarkSecondary,
        AppColors.backgroundSecondary,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('button preserves a 48px accessible target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: FixButton(label: 'Continue', onPressed: () {}),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('card and status chip expose semantic context', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Column(
            children: [
              FixCard(semanticLabel: 'Booking summary', child: Text('Booking')),
              FixStatusChip(
                label: 'Available',
                icon: Icons.check_circle_outline_rounded,
                tone: FixStatusTone.success,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Booking summary'), findsOneWidget);
    expect(find.bySemanticsLabel('Status: Available'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('light information cards use a dark readable foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: FixCard(
            semanticLabel: 'Request details',
            child: Text('Request details'),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Request details'));
    expect(text.style?.color, isNull);
    final defaultStyle = DefaultTextStyle.of(
      tester.element(find.text('Request details')),
    );
    expect(defaultStyle.style.color, AppColors.textOnSurface);
  });

  testWidgets('shared empty, offline, and skeleton states are accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                FixOfflineBanner(),
                FixEmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No bookings yet',
                  message: 'Your bookings will appear here.',
                ),
                FixSkeleton(height: 80),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'You are offline. Some information may be out of date.',
      ),
      findsOneWidget,
    );
    expect(find.text('No bookings yet'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'shared states adapt across phone widths, text scale, and reduced motion',
    (tester) async {
      for (final size in const [
        Size(320, 640),
        Size(390, 844),
        Size(600, 960),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: const MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: FixEmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No incoming jobs',
                      message:
                          'New eligible requests will appear here when you are online.',
                      actionLabel: 'Check availability',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = foreground == lighter ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
