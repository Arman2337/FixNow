import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('NotificationModel', () {
    test('serializes and deserializes correctly with timeAgo', () {
      final notif = InAppNotification(
        id: 'test-1',
        title: 'Booking Update',
        body: 'Provider is arriving soon.',
        category: NotificationCategory.bookings,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        bookingId: 'booking-123',
      );

      final json = notif.toJson();
      expect(json['id'], 'test-1');
      expect(json['category'], 'bookings');

      final deserialized = InAppNotification.fromJson(json);
      expect(deserialized.id, notif.id);
      expect(deserialized.category, NotificationCategory.bookings);
      expect(deserialized.timeAgo, '5m ago');
    });
  });

  group('NotificationController', () {
    test('tracks unread count and applies category filter', () async {
      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();

      expect(controller.notifications.isNotEmpty, isTrue);
      final initialUnread = controller.unreadCount;
      expect(initialUnread, greaterThan(0));

      // Filter by Offers
      controller.setFilter(NotificationCategory.offers);
      expect(controller.selectedCategory, NotificationCategory.offers);
      for (final item in controller.filteredNotifications) {
        expect(item.category, NotificationCategory.offers);
      }

      // Mark all as read
      controller.markAllAsRead();
      expect(controller.unreadCount, 0);

      // Add a new booking alert
      controller.addNotification(
        InAppNotification(
          id: 'dyn-1',
          title: 'Rescheduled',
          body: 'Booking rescheduled successfully',
          category: NotificationCategory.bookings,
          timestamp: DateTime.now(),
          isRead: false,
        ),
      );

      expect(controller.unreadCount, 1);
    });

    test('deletes individual and clears all notifications', () async {
      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();

      final firstId = controller.notifications.first.id;
      controller.deleteNotification(firstId);
      expect(controller.notifications.any((n) => n.id == firstId), isFalse);

      controller.clearAll();
      expect(controller.notifications.isEmpty, isTrue);
      expect(controller.unreadCount, 0);
    });
  });

  group('FixNotificationBellIcon widget', () {
    testWidgets('renders badge counter and fires onTap', (tester) async {
      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();

      bool tapped = false;

      await tester.pumpWidget(
        host(
          FixNotificationBellIcon(
            controller: controller,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FixNotificationBellIcon), findsOneWidget);
      expect(find.text('${controller.unreadCount}'), findsOneWidget);

      await tester.tap(find.byType(FixNotificationBellIcon));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('NotificationCenterScreen widget', () {
    testWidgets('renders activity list, filters by tab, and opens booking detail',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();

      String? openedBookingId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NotificationCenterScreen(
            controller: controller,
            onOpenBooking: (id) => openedBookingId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications & Activity'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Offers'), findsOneWidget);

      // Tap on Bookings filter chip
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory, NotificationCategory.bookings);

      // Tap on booking notification card
      final bookingCard = find.text('Booking Confirmed & Assigned');
      expect(bookingCard, findsOneWidget);
      await tester.tap(bookingCard);
      await tester.pumpAndSettle();

      expect(openedBookingId, 'booking-seed-1');

      // Test "Mark read" button
      if (controller.unreadCount > 0) {
        await tester.tap(find.text('Mark read'));
        await tester.pumpAndSettle();
        expect(controller.unreadCount, 0);
      }
    });

    testWidgets('displays comforting empty state when category has no notifications',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();
      controller.clearAll();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NotificationCenterScreen(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are all caught up!'), findsOneWidget);
    });

    testWidgets('read notifications maintain high-contrast dark theme surfaces without white-on-white text',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = NotificationRepository();
      final controller = NotificationController(repository);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NotificationCenterScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verify unread notifications
      expect(find.text('Booking Confirmed & Assigned'), findsOneWidget);
      expect(find.text('Seasonal Home Checkup'), findsOneWidget);

      // Verify read notifications are rendered legibly
      expect(find.text('Payment Invoice Ready'), findsOneWidget);
      expect(find.text('Trust & Safety Assurance'), findsOneWidget);

      // Find the text widget for read notification and verify it uses high contrast text color
      final readTitle = tester.widget<Text>(find.text('Payment Invoice Ready'));
      expect(readTitle.style?.color, isNotNull);
      // Ensure text is high contrast cream/white (not dark text that blends into dark bg)
      expect(readTitle.style!.color!.computeLuminance(), greaterThan(0.5));
    });
  });
}
