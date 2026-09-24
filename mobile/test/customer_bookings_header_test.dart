import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:fixnow_mobile/app/app_shell_controller.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(
      statusCode: 200,
      body: {'bookings': <Map<String, dynamic>>[]},
    );
  }
}

InAppNotification _push(String id) => InAppNotification(
  id: id,
  title: 'Booking Update',
  body: 'Provider accepted.',
  category: NotificationCategory.bookings,
  timestamp: DateTime.now(),
  isRead: false,
);

void main() {
  testWidgets('tapping customer profile button invokes onOpenProfile callback', (
    tester,
  ) async {
    final controller = BookingController(
      BookingRepository(api: _FakeTransport(), accessToken: () async => 'token'),
    );
    var profileTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CustomerBookingsScreen(
            controller: controller,
            onOpenProfile: () {
              profileTapped = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the profile button exists via tooltip
    final profileButton = find.byTooltip('Profile');
    expect(profileButton, findsOneWidget);

    await tester.tap(profileButton);
    await tester.pumpAndSettle();

    expect(profileTapped, isTrue);
  });

  testWidgets('tapping customer profile button delegates to AppShellScope when callback is null', (
    tester,
  ) async {
    final controller = BookingController(
      BookingRepository(api: _FakeTransport(), accessToken: () async => 'token'),
    );
    final shellController = AppShellController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShellScope(
          controller: shellController,
          child: Scaffold(
            body: CustomerBookingsScreen(
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(shellController.selectedIndex, 0);

    final profileButton = find.byTooltip('Profile');
    expect(profileButton, findsOneWidget);

    await tester.tap(profileButton);
    await tester.pumpAndSettle();

    // Switched to Profile destination (index 3)
    expect(shellController.selectedIndex, 3);
  });

  testWidgets('notification bell icon is clearly visible with primary color when unread', (
    tester,
  ) async {
    final notifController = NotificationController(NotificationRepository());
    await notifController.load();
    notifController.clearAll();
    notifController.markAllAsRead();
    notifController.addNotification(_push('notif-1'));
    notifController.addNotification(_push('notif-2'));

    expect(notifController.unreadCount, 2);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FixNotificationBellIcon(
            controller: notifController,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the bell icon is present with AppColors.primary (not white)
    final bellIcon = tester.widget<Icon>(find.byType(Icon));
    expect(bellIcon.icon, Icons.notifications_active_rounded);
    expect(bellIcon.color, AppColors.primary);
    expect(find.text('2'), findsOneWidget);
  });
}
