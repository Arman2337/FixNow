import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'provider applicant sees truthful incomplete verification state',
    (tester) async {
      final controller = ProviderController(
        ProviderRepository(
          api: _ProviderTransport(verified: false),
          accessToken: () async => 'token',
        ),
      );
      await controller.load(verified: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProviderOnboardingScreen(
            controller: controller,
            onSignOut: () {},
          ),
        ),
      );
      expect(find.text('Profile incomplete'), findsOneWidget);
      expect(find.text('Identity documents'), findsOneWidget);
      expect(find.textContaining('never shown publicly'), findsOneWidget);
    },
  );

  testWidgets('verified provider sees availability without fake work', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: true),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ProviderHomeScreen(controller: controller)),
      ),
    );
    expect(find.text('Offline'), findsWidgets);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('Go online to receive'), findsOneWidget);
    expect(find.textContaining('No active jobs'), findsOneWidget);
    expect(find.textContaining('earnings'), findsNothing);
  });

  testWidgets('verified provider sees an eligible incoming request preview', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: true),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'category-1',
        description: 'Kitchen sink leak',
        createdAt: DateTime.utc(2026, 8, 14),
        version: 1,
        distanceKm: 1.2,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ProviderHomeScreen(controller: controller)),
      ),
    );

    expect(find.text('Incoming requests'), findsOneWidget);
    expect(find.text('Category 1'), findsOneWidget);
    expect(find.text('Kitchen sink leak'), findsOneWidget);
    expect(find.text('About 1.2 km away'), findsOneWidget);
    expect(
      find.text(
        'Customer address and contact details appear only after you accept.',
      ),
      findsOneWidget,
    );
    final localRequestTime = DateTime.utc(2026, 8, 14).toLocal();
    expect(
      find.text(
        'Requested ${localRequestTime.day}/${localRequestTime.month} · '
        '${localRequestTime.hour.toString().padLeft(2, '0')}:'
        '${localRequestTime.minute.toString().padLeft(2, '0')}',
      ),
      findsOneWidget,
    );
    expect(find.text('Accept request'), findsOneWidget);
  });

  testWidgets('shows the usual accept-time signal when data is sufficient', (
    tester,
  ) async {
    final controller = _loadedVerifiedController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ProviderHomeScreen(
            controller: controller,
            loadAcceptTime: () async => const ProviderAcceptTime(
              averageAcceptMinutes: 21,
              sampleSize: 9,
              windowDays: 90,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('about 21 min'), findsOneWidget);
    expect(find.textContaining('9 accepted jobs'), findsOneWidget);
    expect(find.bySemanticsLabel('Your usual accept time'), findsOneWidget);
  });

  testWidgets('hides the accept-time card entirely when data is insufficient', (
    tester,
  ) async {
    final controller = _loadedVerifiedController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ProviderHomeScreen(
            controller: controller,
            loadAcceptTime: () async => const ProviderAcceptTime(
              averageAcceptMinutes: null,
              sampleSize: 1,
              windowDays: 90,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Your usual accept time'), findsNothing);
    expect(find.textContaining('usual accept time'), findsNothing);
  });

  testWidgets(
    'verified provider sees notification banner when unread alerts exist and can open notification',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = _loadedVerifiedController();
      final notifRepo = NotificationRepository();
      final notifController = NotificationController(notifRepo);
      await notifController.load();

      String? openedBooking;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ProviderHomeScreen(
              controller: controller,
              notificationController: notifController,
              onOpenBooking: (id) => openedBooking = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Provider Notification Banner should be displayed with the unread notification
      expect(find.text('Booking Confirmed & Assigned'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('View Booking'), findsOneWidget);

      // Tap on the notification banner
      await tester.tap(find.text('Booking Confirmed & Assigned'));
      await tester.pumpAndSettle();

      expect(openedBooking, 'booking-seed-1');
    },
  );

  testWidgets('verified provider can dismiss notification banner', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = _loadedVerifiedController();
    final notifRepo = NotificationRepository();
    final notifController = NotificationController(notifRepo);
    await notifController.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ProviderHomeScreen(
            controller: controller,
            notificationController: notifController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking Confirmed & Assigned'), findsOneWidget);

    // Tap dismiss (close icon button)
    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pumpAndSettle();

    // That notification is dismissed/marked read, so the next unread notification appears
    expect(find.text('Booking Confirmed & Assigned'), findsNothing);
    expect(find.text('Seasonal Home Checkup'), findsOneWidget);
  });

  test('on-site adjustment sends drafts and refreshes the job totals', () async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(
        api: transport,
        accessToken: () async => 'token',
      ),
    );
    final job = CustomerBooking(
      id: 'job-1',
      serviceCategoryId: 'plumbing',
      status: 'IN_PROGRESS',
      description: 'Kitchen sink pipe is leaking heavily.',
      createdAt: DateTime.parse('2026-09-08T09:00:00.000Z'),
      version: 2,
    );
    controller.jobs = [job];

    final updated = await controller.updateJobItems(job, const [
      BookingItemDraft(
        id: 'on-site-1',
        name: 'New tap cartridge',
        quantity: 2,
        unitPriceMinor: 24900,
      ),
    ]);

    expect(updated, isNotNull);
    expect(updated!.items?.single.name, 'New tap cartridge');
    expect(updated.pricing?.totalMinor, 58764);
    expect(updated.estimatedDurationMinutes, 90);
    expect(controller.jobs.single.version, 3);

    final body = transport.requests.last.body!;
    expect(body['expectedVersion'], 2);
    expect((body['items'] as List).single, {
      'id': 'on-site-1',
      'name': 'New tap cartridge',
      'quantity': 2,
      'unitPriceMinor': 24900,
    });
  });

  test('on-site adjustment surfaces a conflict without losing the job', () async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: true, itemsConflict: true),
        accessToken: () async => 'token',
      ),
    );
    final job = CustomerBooking(
      id: 'job-1',
      serviceCategoryId: 'plumbing',
      status: 'IN_PROGRESS',
      description: 'Kitchen sink pipe is leaking heavily.',
      createdAt: DateTime.parse('2026-09-08T09:00:00.000Z'),
      version: 2,
    );
    controller.jobs = [job];

    final updated = await controller.updateJobItems(job, const [
      BookingItemDraft(
        id: 'on-site-1',
        name: 'New tap cartridge',
        quantity: 1,
        unitPriceMinor: 24900,
      ),
    ]);

    expect(updated, isNull);
    expect(controller.actionError, isNotNull);
    expect(controller.jobs.single.version, 2);
  });
}

ProviderController _loadedVerifiedController() {
  final controller = ProviderController(
    ProviderRepository(
      api: _ProviderTransport(verified: true),
      accessToken: () async => 'token',
    ),
  );
  controller.load(verified: true);
  return controller;
}

class _ProviderTransport implements ApiTransport {
  _ProviderTransport({required this.verified, this.itemsConflict = false});
  final bool verified;
  final bool itemsConflict;
  final List<ApiRequest> requests = [];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path == 'bookings/job-1/items') {
      if (itemsConflict) {
        // Mirror ApiClient, which converts non-2xx into ApiException.
        throw const ApiException(
          ApiFailureKind.server,
          'Booking version is stale',
          statusCode: 409,
        );
      }
      return const ApiResponse(
        statusCode: 200,
        body: {
          'booking': {
            'id': 'job-1',
            'serviceCategoryId': 'plumbing',
            'status': 'IN_PROGRESS',
            'description': 'Kitchen sink pipe is leaking heavily.',
            'createdAt': '2026-09-08T09:00:00.000Z',
            'version': 3,
            'items': [
              {
                'id': 'on-site-1',
                'name': 'New tap cartridge',
                'quantity': 2,
                'unitPriceMinor': 24900,
              },
            ],
            'pricing': {
              'subtotalMinor': 49800,
              'gstMinor': 8964,
              'totalMinor': 58764,
              'currency': 'INR',
            },
            'estimatedDurationMinutes': 90,
          },
        },
      );
    }
    if (request.path == 'provider-applications/me') {
      return ApiResponse(
        statusCode: 200,
        body: {
          'status': verified ? 'approved' : 'unverified',
          'decisionReason': null,
        },
      );
    }
    if (request.path == 'provider-profile/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'displayName': 'Amina Services',
          'bio': 'Licensed professional',
          'serviceRadiusKm': 15,
          'baseLatitude': 25.2,
          'baseLongitude': 55.3,
        },
      );
    }
    if (request.path == 'provider-availability/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {'status': 'offline', 'version': 2},
      );
    }
    if (request.path == 'provider-skills/me') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (request.path == 'service-categories') {
      return const ApiResponse(
        statusCode: 200,
        body: {'categories': <Object?>[]},
      );
    }
    if (request.path == 'provider-documents') {
      return const ApiResponse(
        statusCode: 200,
        body: {'documents': <Object?>[]},
      );
    }
    if (request.path.startsWith('bookings?') ||
        request.path.startsWith('bookings/available?')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    throw const ApiException(
      ApiFailureKind.invalidResponse,
      'Unexpected request',
    );
  }
}
