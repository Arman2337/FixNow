import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_eta_ring.dart';
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
    expect(AppMotion.container, const Duration(milliseconds: 340));
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
    expect(
      _contrastRatio(AppColors.textOnSurfaceMuted, AppColors.surfacePrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('every status chip tone holds 4.5:1 on its own background', () {
    for (final tone in FixStatusTone.values) {
      final (foreground, background) = FixStatusChip.colorsFor(tone);
      expect(
        _contrastRatio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '${tone.name} chip foreground must meet AA on its background',
      );
    }
  });

  test('on-light accent steps hold AA on light surfaces and soft chips', () {
    const lightSurfaces = [
      AppColors.surfacePrimary,
      AppColors.surfaceSecondary,
      AppColors.cream,
    ];
    final pairs = <(Color, Color, List<Color>)>[
      (AppColors.successOnLight, AppColors.successSoft, lightSurfaces),
      (AppColors.warningOnLight, AppColors.warningSoft, lightSurfaces),
      (AppColors.dangerOnLight, AppColors.dangerSoft, lightSurfaces),
      (AppColors.ratingOnLight, AppColors.accentGoldSoft, lightSurfaces),
      (AppColors.infoOnLight, AppColors.infoSoft, lightSurfaces),
    ];
    for (final (foreground, soft, surfaces) in pairs) {
      expect(
        _contrastRatio(foreground, soft),
        greaterThanOrEqualTo(4.5),
        reason: 'on-light step must meet AA on its soft chip background',
      );
      for (final surface in surfaces) {
        expect(
          _contrastRatio(foreground, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'on-light step must meet AA on light card surfaces',
        );
      }
    }
  });

  testWidgets('eta ring renders minutes, dash for null, and static fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EtaProgressRing(minutes: 12),
              EtaProgressRing(minutes: null),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('eta ring settles under reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: EtaProgressRing(minutes: 7))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
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

  testWidgets('success morph shows the check, swaps the label, and disables', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: FixButton(
              label: 'Confirm visit',
              success: true,
              successLabel: 'Visit booked',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Visit booked'), findsOneWidget);
    expect(find.text('Confirm visit'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0, reason: 'success button must not accept taps');
    final handler = semantics;
    handler.dispose();
  });

  testWidgets('success morph settles under reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: FixButton(label: 'Go', success: true, onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    // Reduced motion renders a static success child — settle must terminate.
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
