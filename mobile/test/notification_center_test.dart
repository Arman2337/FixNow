import 'dart:async';
import 'dart:convert';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingNotificationTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(statusCode: 503, body: <Object?>{});
  }
}

class _FixtureNotificationTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final now = DateTime.now().toUtc();
    return ApiResponse(
      statusCode: 200,
      body: [
        {
          'id': 'booking-1',
          'title': 'Booking Confirmed & Assigned',
          'body': 'Your booking is confirmed.',
          'category': 'bookings',
          'timestamp': now.subtract(const Duration(minutes: 18)).toIso8601String(),
          'bookingId': 'booking-1',
          'isRead': false,
        },
        {
          'id': 'offer-1',
          'title': 'Seasonal Home Checkup',
          'body': 'Book a seasonal home checkup.',
          'category': 'offers',
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'isRead': false,
        },
        {
          'id': 'payment-1',
          'title': 'Payment Invoice Ready',
          'body': 'Invoice for Plumbing Service is ready.',
          'category': 'payments',
          'timestamp': now.subtract(const Duration(hours: 18)).toIso8601String(),
          'paymentId': 'payment-1',
          'serviceName': 'Plumbing Service',
          'isRead': true,
        },
        {
          'id': 'system-1',
          'title': 'Trust & Safety Assurance',
          'body': 'Your account is protected.',
          'category': 'system',
          'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
          'isRead': true,
        },
      ],
    );
  }
}

NotificationRepository fixtureRepository() => NotificationRepository(
  api: _FixtureNotificationTransport(),
  accessToken: () async => 'token',
);

class _NotificationSocket implements RealtimeSocket {
  final _messages = StreamController<Object?>();
  final sent = <String>[];

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> send(Object message) async {
    sent.add(message.toString());
    final value = jsonDecode(message.toString()) as Map<String, dynamic>;
    if (value['type'] == 'authenticate') {
      Future<void>.delayed(Duration.zero, () => emit({'type': 'ready'}));
    } else if (value['type'] == 'subscribe') {
      Future<void>.delayed(Duration.zero, () => emit({
            'type': 'subscribed',
            'requestId': value['requestId'],
            'channel': value['channel'],
            'resourceId': value['resourceId'],
          }));
    }
  }

  void emit(Map<String, Object?> message) => _messages.add(jsonEncode(message));

  @override
  Future<void> close() => _messages.close();
}

class _NotificationConnector implements RealtimeSocketConnector {
  const _NotificationConnector(this.socket);

  final _NotificationSocket socket;

  @override
  Future<RealtimeSocket> connect(Uri uri) async => socket;
}

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  test('does not return seed data when the notification API is unavailable', () async {
    final repository = NotificationRepository(
      api: _FailingNotificationTransport(),
      accessToken: () async => 'token',
    );

    final controller = NotificationController(repository);
    await controller.load();

    expect(controller.notifications, isEmpty);
    expect(controller.hasError, isTrue);
  });

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
      final repository = fixtureRepository();
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

    test('adds a notification delivered by the account realtime stream', () async {
      final socket = _NotificationSocket();
      final realtime = RealtimeClient(
        uri: Uri.parse('ws://localhost/realtime'),
        accessToken: () async => 'access-token',
        connector: _NotificationConnector(socket),
      );
      final controller = NotificationController(
        fixtureRepository(),
        realtime: realtime,
      );
      await controller.load();
      final received = Completer<void>();
      controller.addListener(() {
        if (controller.notifications.any((item) => item.id == 'realtime-1') &&
            !received.isCompleted) {
          received.complete();
        }
      });

      await realtime.subscribeAccount('user-1');
      socket.emit({
        'type': 'notification.created.v1',
        'data': {
          'id': 'realtime-1',
          'title': 'Realtime update',
          'body': 'A new update arrived.',
          'category': 'bookings',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'isRead': false,
        },
      });

      await received.future.timeout(const Duration(seconds: 1));
      expect(controller.notifications.first.id, 'realtime-1');
      controller.dispose();
      realtime.dispose();
    });

    test('deletes individual and clears all notifications', () async {
      final repository = fixtureRepository();
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
      final repository = fixtureRepository();
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
    testWidgets(
      'renders activity list, filters by tab, and opens booking detail',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = fixtureRepository();
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

        expect(openedBookingId, 'booking-1');

        // Test "Mark read" button
        if (controller.unreadCount > 0) {
          await tester.tap(find.text('Mark read'));
          await tester.pumpAndSettle();
          expect(controller.unreadCount, 0);
        }
      },
    );

    testWidgets(
      'displays comforting empty state when category has no notifications',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = fixtureRepository();
        final controller = NotificationController(repository);
        await controller.load();
        controller.clearAll();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: NotificationCenterScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('You are all caught up!'), findsOneWidget);
      },
    );

    testWidgets(
      'read notifications maintain high-contrast dark theme surfaces without white-on-white text',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = fixtureRepository();
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
        final readTitle = tester.widget<Text>(
          find.text('Payment Invoice Ready'),
        );
        expect(readTitle.style?.color, isNotNull);
        // Ensure text is high contrast cream/white (not dark text that blends into dark bg)
        expect(readTitle.style!.color!.computeLuminance(), greaterThan(0.5));
      },
    );

    testWidgets(
      'renders View Invoice on payment notifications and triggers onOpenInvoice',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = fixtureRepository();
        final controller = NotificationController(repository);
        await controller.load();

        InAppNotification? openedInvoice;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: NotificationCenterScreen(
              controller: controller,
              onOpenInvoice: (item) => openedInvoice = item,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Payments tab
        await tester.tap(find.text('Payments'));
        await tester.pumpAndSettle();

        // Verify View Invoice button is visible
        expect(find.text('View Invoice'), findsOneWidget);

        // Tap on View Invoice / Payment notification
        await tester.tap(find.text('Payment Invoice Ready'));
        await tester.pumpAndSettle();

        expect(openedInvoice, isNotNull);
        expect(openedInvoice?.title, 'Payment Invoice Ready');
        expect(openedInvoice?.category, NotificationCategory.payments);
      },
    );

    testWidgets(
      'displays fallback invoice modal when onOpenInvoice is not supplied',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = fixtureRepository();
        final controller = NotificationController(repository);
        await controller.load();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: NotificationCenterScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Payments tab
        await tester.tap(find.text('Payments'));
        await tester.pumpAndSettle();

        // Tap on Payment Invoice Ready card
        await tester.tap(find.text('Payment Invoice Ready'));
        await tester.pumpAndSettle();

        // Modal sheet should be open
         expect(find.text('Invoice'), findsOneWidget);
         expect(
           find.text(
             'Open the payment details to view the authoritative invoice, amount, and status.',
           ),
           findsOneWidget,
         );
         expect(find.text('PAID'), findsNothing);
         expect(find.text('₹649'), findsNothing);

         // Tap close button on modal
         await tester.tap(find.text('Close'));
         await tester.pumpAndSettle();

         expect(find.text('Invoice'), findsNothing);
      },
    );
  });
}
