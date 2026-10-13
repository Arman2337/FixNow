import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_saved_data_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);

  testWidgets('banner states that the data is saved and when it arrived', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FixSavedDataBanner(
          savedAt: now.subtract(const Duration(minutes: 12)),
          now: now,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Showing saved data'), findsOneWidget);
    expect(find.text('Updated 12m ago · may be out of date'), findsOneWidget);
  });

  testWidgets('banner renders nothing when there is no saved data', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FixSavedDataBanner()));

    expect(find.byType(FixSavedDataBanner), findsOneWidget);
    expect(find.textContaining('saved'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
  });

  testWidgets('banner announces the staleness to screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(FixSavedDataBanner(savedAt: now, now: now)),
    );
    await tester.pump();

    final label = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .join(' | ');
    expect(label, contains('Showing saved data'));
    expect(label, contains('Updated just now'));
    expect(label, contains('may be out of date'));
  });

  testWidgets('banner offers a retry that fires the callback', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _wrap(
        FixSavedDataBanner(
          savedAt: now.subtract(const Duration(hours: 3)),
          now: now,
          onRetry: () => retries += 1,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('banner hides the retry when there is nothing to retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(FixSavedDataBanner(savedAt: now, now: now)),
    );
    await tester.pump();

    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('banner survives 200% text scale without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FixSavedDataBanner(
          savedAt: now.subtract(const Duration(days: 2)),
          now: now,
          onRetry: () {},
        ),
        textScale: 2,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Showing saved data'), findsOneWidget);
    expect(find.text('Updated 2d ago · may be out of date'), findsOneWidget);
  });

  test('the stamp uses the shared human-readable age', () {
    expect(fixSavedDataAgeText(now.subtract(const Duration(minutes: 8)), now: now), 'Updated 8m ago');
    expect(fixSavedDataAgeText(now.subtract(const Duration(days: 3)), now: now), 'Updated 3d ago');
  });
}