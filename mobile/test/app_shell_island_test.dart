import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_active_booking_island.dart';
import 'package:fixnow_mobile/design_system/fix_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('island renders above the bottom navigation when supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShell(
          activeBookingIsland: FixActiveBookingIsland(
            serviceLabel: 'Plumbing',
            statusLabel: 'On the way to you',
            onTap: () {},
          ),
          customerHome: const SizedBox.shrink(),
          customerBookings: const SizedBox.shrink(),
          customerHelp: const SizedBox.shrink(),
          customerProfile: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FixActiveBookingIsland), findsOneWidget);
    expect(find.text('On the way to you'), findsOneWidget);

    // The island sits above the nav bar in the widget tree.
    final islandY = tester.getTopLeft(find.byType(FixActiveBookingIsland)).dy;
    final navY = tester.getTopLeft(find.byType(FixBottomNavigation)).dy;
    expect(islandY, lessThan(navY));

    // Navigation still works with the island present.
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(AppNavigation.forRole(AppShellRole.customer), isNotEmpty);
  });

  testWidgets('shell renders no island when no booking is live', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AppShell(
          customerHome: SizedBox.shrink(),
          customerBookings: SizedBox.shrink(),
          customerHelp: SizedBox.shrink(),
          customerProfile: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FixActiveBookingIsland), findsNothing);
    expect(find.byType(FixBottomNavigation), findsOneWidget);
  });
}
