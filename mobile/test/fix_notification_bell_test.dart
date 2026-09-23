import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: Center(child: child)),
  ),
);

InAppNotification _push(String id) => InAppNotification(
  id: id,
  title: 'Booking Update',
  body: 'Provider accepted.',
  category: NotificationCategory.bookings,
  timestamp: DateTime.now(),
  isRead: false,
);

void main() {
  testWidgets('new notification shows badge, active icon, and shake', (
    tester,
  ) async {
    final controller = NotificationController(NotificationRepository());
    await controller.load();
    controller.clearAll();
    controller.markAllAsRead();

    await tester.pumpWidget(
      host(FixNotificationBellIcon(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    controller.addNotification(_push('dyn-shake-1'));
    // Mid-shake: the rotate transform exists.
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(Transform), findsWidgets);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('marking read clears the badge without shaking', (tester) async {
    final controller = NotificationController(NotificationRepository());
    await controller.load();
    controller.markAllAsRead();
    controller.addNotification(_push('dyn-read-1'));

    await tester.pumpWidget(
      host(FixNotificationBellIcon(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    controller.markAllAsRead();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(controller.unreadCount, 0);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('reduce motion skips the shake but keeps the badge accurate', (
    tester,
  ) async {
    final controller = NotificationController(NotificationRepository());
    await controller.load();
    controller.clearAll();
    controller.markAllAsRead();

    await tester.pumpWidget(
      host(
        FixNotificationBellIcon(controller: controller),
        disableAnimations: true,
      ),
    );
    await tester.pump();

    controller.addNotification(_push('dyn-calm-1'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(controller.unreadCount, 1);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
  });
}
