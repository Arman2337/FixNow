import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme exposes the approved semantic colors', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('button preserves a 48px accessible target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
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
        theme: AppTheme.light,
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
}
