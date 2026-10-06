import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_incoming_request_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_jobs_screen.dart';
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

  testWidgets('KYC progress counts only approved required documents', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: false),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: false);
    controller.documents = [
      const ProviderDocument(
        id: 'aadhaar-1',
        type: 'aadhaar',
        status: 'APPROVED',
        sizeBytes: 1,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProviderOnboardingScreen(
          controller: controller,
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('1 of 4 Verified'), findsOneWidget);
    expect(find.text('25% Complete'), findsOneWidget);
    expect(find.text('Step 2 of 4'), findsOneWidget);
  });
  testWidgets('under-review KYC does not claim complete documents', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: false),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: false);
    controller.application = const ProviderApplication(
      status: ProviderApplicationStatus.underReview,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProviderOnboardingScreen(
          controller: controller,
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('4 of 4 Verified'), findsNothing);
    expect(find.text('100% Complete'), findsNothing);
  });

  testWidgets('approved KYC does not fabricate missing approved documents', (
    tester,
  ) async {
    final controller = ProviderController(
      ProviderRepository(
        api: _ProviderTransport(verified: false),
        accessToken: () async => 'token',
      ),
    );
    await controller.load(verified: false);
    controller.application = const ProviderApplication(
      status: ProviderApplicationStatus.approved,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProviderOnboardingScreen(
          controller: controller,
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('4 of 4 Verified'), findsNothing);
  });

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
    expect(find.text('New Request Available!'), findsOneWidget);
    expect(find.text('ACTION NEEDED'), findsOneWidget);
    expect(find.textContaining('Tap to review and accept'), findsOneWidget);
    await tester.tap(find.text('New Request Available!'));
    await tester.pumpAndSettle();

    expect(find.text('Accept request'), findsOneWidget);
  });

  // Regression: every history card rendered a hardcoded "Rating ★ 5.0" and the
  // working-hours card rendered hardcoded "8 km Radius" / "09:00 - 19:30", so
  // the provider saw a perfect score and a schedule nobody had set.
  group('history tab shows real data, never invented values', () {
    Future<void> openHistory(WidgetTester tester) async {
      final controller = ProviderController(
        ProviderRepository(
          api: _ProviderTransport(verified: true),
          accessToken: () async => 'token',
        ),
      );
      await controller.load(verified: true);
      controller.jobs = [
        CustomerBooking(
          id: 'job-history-1',
          serviceCategoryId: 'ac_repair',
          status: 'COMPLETED',
          description: 'AC servicing',
          createdAt: DateTime.utc(2026, 8, 14),
          version: 4,
        ),
      ];
      controller.profile = ProviderProfile(
        displayName: 'Test Tech',
        bio: '',
        serviceRadiusKm: 12,
        baseLatitude: 23.02,
        baseLongitude: 72.57,
        stats: const ProviderStats(
          rating: 0,
          reviewCount: 0,
          completedJobs: 3,
          earningsMinor: 0,
          acceptanceRate: 0,
        ),
      );
      controller.availability = const ProviderAvailability(
        status: 'online',
        version: 1,
        timeZone: 'Asia/Kolkata',
        weeklyRules: [],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ProviderJobsScreen(controller: controller, showHistory: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an unrated provider is not shown a 5.0 score', (tester) async {
      await openHistory(tester);

      expect(find.textContaining('Not yet rated'), findsWidgets);
      expect(find.textContaining('Rating ★ 5.0'), findsNothing);
      expect(find.textContaining('Rating ★'), findsNothing);
    });

    testWidgets('working hours and radius come from the profile', (
      tester,
    ) async {
      await openHistory(tester);

      expect(find.textContaining('12 km Radius'), findsOneWidget);
      expect(find.textContaining('8 km Radius'), findsNothing);
      // weeklyRules is empty, so the honest summary is the model's own
      // "no recurring hours set" wording rather than an invented time range.
      expect(find.text('No recurring hours set.'), findsOneWidget);
      expect(find.text('09:00 - 19:30'), findsNothing);
    });
  });

  // Regression: the incoming request banner title was AppColors.cream
  // (#FFFFFF) on a surfaceElevated (#FFFFFF) card, i.e. 1.0:1 - the
  // "New Request Available!" headline was invisible while the sub-line
  // underneath it read fine, which made the card look like it had lost its
  // heading.

  testWidgets('incoming request banner text is legible on its white card', (
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
        distanceKm: 0.0,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ProviderHomeScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    Color styleOf(String label) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: 'missing label: $label');
      final text = tester.widget<Text>(finder);
      return text.style?.color ??
          DefaultTextStyle.of(tester.element(finder)).style.color!;
    }

    // Both sit on the white card, so both must clear AA against white.
    for (final label in const [
      'New Request Available!',
      '0.0 km away · Tap to review and accept',
    ]) {
      expect(
        _contrastRatio(styleOf(label), AppColors.surfaceElevated),
        greaterThanOrEqualTo(4.5),
        reason: '"$label" must meet AA on the white request card',
      );
    }

    // The gold badge keeps dark ink on gold; the gold accents must not rely on
    // raw #F59E0B against white.
    expect(
      _contrastRatio(styleOf('ACTION NEEDED'), AppColors.accentGold),
      greaterThanOrEqualTo(4.5),
    );
    final radar = tester.widget<Icon>(find.byIcon(Icons.radar_rounded).first);
    expect(
      _contrastRatio(
        radar.color!,
        Color.alphaBlend(
          AppColors.accentGold.withValues(alpha: 0.18),
          AppColors.surfaceElevated,
        ),
      ),
      greaterThanOrEqualTo(4.5),
      reason: 'radar icon must read against its own gold-tinted disc',
    );
  });

  testWidgets('incoming request acceptance sends the current booking version', (
    tester,
  ) async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProviderIncomingRequestScreen(
          providerController: controller,
          requestData: {
            'bookingId': 'request-1',
            'serviceCategoryId': 'plumbing',
            'description': 'Kitchen sink leak',
            'version': 4,
            'createdAt': '2026-08-14T10:00:00.000Z',
            'distanceKm': 1.2,
            'priceMinor': '45000',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final acceptRequest = transport.requests.last;
    expect(acceptRequest.path, 'bookings/request-1/accept');
    expect(acceptRequest.body?['expectedVersion'], 4);
  });

  // A second tap must not become a second POST. Before the controller-level
  // guard, two accepts for the same booking raced: the backend answered the
  // loser with `Booking version is stale`, and the UI reported a failure for
  // work it had already done.
  test('a second accept for the same request sends only one POST', () async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'plumbing',
        description: 'Kitchen sink leak',
        version: 4,
        distanceKm: 1.2,
        createdAt: DateTime.parse('2026-08-14T10:00:00.000Z'),
      ),
    ];
    final request = controller.requests.single;

    // Both taps land before the first has resolved, which is the window where a
    // duplicate is actually possible.
    final results = await Future.wait([
      controller.acceptRequest(request),
      controller.acceptRequest(request),
    ]);

    final accepts = transport.requests
        .where((r) => r.path.endsWith('/accept'))
        .toList();
    expect(accepts, hasLength(1));
    // Both callers learn the same outcome, rather than the second being told it
    // failed for work the first was already completing.
    expect(results, [true, true]);
  });

  test('the accept button is disabled while an accept is in flight', () async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'plumbing',
        description: 'Kitchen sink leak',
        version: 4,
        distanceKm: 1.2,
        createdAt: DateTime.parse('2026-08-14T10:00:00.000Z'),
      ),
    ];

    expect(controller.isAcceptingRequest('request-1'), isFalse);
    final pending = controller.acceptRequest(controller.requests.single);
    expect(controller.isAcceptingRequest('request-1'), isTrue);
    await pending;
    // Cleared afterwards, or the card would stay permanently disabled for any
    // request the provider did not go on to accept.
    expect(controller.isAcceptingRequest('request-1'), isFalse);
  });

  test('an in-flight flag is per request, so one accept does not block others', () async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'plumbing',
        description: 'First',
        version: 4,
        distanceKm: 1.2,
        createdAt: DateTime.parse('2026-08-14T10:00:00.000Z'),
      ),
      ProviderRequest(
        id: 'request-2',
        serviceCategoryId: 'electrical',
        description: 'Second',
        version: 7,
        distanceKm: 3.4,
        createdAt: DateTime.parse('2026-08-14T10:05:00.000Z'),
      ),
    ];

    final pending = controller.acceptRequest(controller.requests.first);
    // The home screen renders a card per request, so a single screen-wide flag
    // would freeze every other card while one accept was in flight.
    expect(controller.isAcceptingRequest('request-2'), isFalse);
    await pending;
  });

  testWidgets('tapping accept twice on the dialog posts once', (tester) async {
    final transport = _ProviderTransport(verified: true);
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);
    controller.requests = [
      ProviderRequest(
        id: 'request-1',
        serviceCategoryId: 'plumbing',
        description: 'Kitchen sink leak',
        version: 4,
        distanceKm: 1.2,
        createdAt: DateTime.parse('2026-08-14T10:00:00.000Z'),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProviderIncomingRequestScreen(
          providerController: controller,
          requestData: {
            'bookingId': 'request-1',
            'serviceCategoryId': 'plumbing',
            'description': 'Kitchen sink leak',
            'version': 4,
            'createdAt': '2026-08-14T10:00:00.000Z',
            'distanceKm': 1.2,
            'priceMinor': '45000',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Two taps with no pump between them: the second lands while the first
    // request is still in flight.
    await tester.tap(find.text('Accept'));
    await tester.tap(find.text('Accept'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final accepts = transport.requests
        .where((r) => r.path.endsWith('/accept'))
        .toList();
    expect(accepts, hasLength(1));
  });

  testWidgets(
    'provider home does not report success after an acceptance conflict',
    (tester) async {
      final transport = _ProviderTransport(
        verified: true,
        acceptConflict: true,
      );
      final controller = ProviderController(
        ProviderRepository(api: transport, accessToken: () async => 'token'),
      );
      await controller.load(verified: true);
      controller.requests = [
        ProviderRequest(
          id: 'request-conflict',
          serviceCategoryId: 'category-1',
          description: 'Already assigned request',
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
      await tester.ensureVisible(find.text('Accept request'));
      await tester.tap(find.text('Accept request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        transport.requests.any(
          (request) => request.path == 'bookings/request-conflict/accept',
        ),
        isTrue,
      );
      expect(find.text('Request accepted!'), findsNothing);
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(controller.requests, hasLength(1));
    },
  );

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
      final notifRepo = NotificationRepository(
        api: _ProviderNotificationTransport(),
        accessToken: () async => 'token',
      );
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

  testWidgets('provider notification banner keeps readable title text', (
    tester,
  ) async {
    final controller = _loadedVerifiedController();
    final notifRepo = NotificationRepository(
      api: _ProviderNotificationTransport(),
      accessToken: () async => 'token',
    );
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

    final title = tester.widget<Text>(
      find.text('Booking Confirmed & Assigned'),
    );
    expect(title.style?.color, AppColors.textPrimary);
    notifController.dispose();
  });

  testWidgets('verified provider can dismiss notification banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = _loadedVerifiedController();
    final notifRepo = NotificationRepository(
      api: _ProviderNotificationTransport(),
      accessToken: () async => 'token',
    );
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

  test(
    'on-site adjustment sends drafts and refreshes the job totals',
    () async {
      final transport = _ProviderTransport(verified: true);
      final controller = ProviderController(
        ProviderRepository(api: transport, accessToken: () async => 'token'),
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
        // Only the catalogue entry and quantity travel to the server (SEC-001).
        BookingItemDraft(subServiceId: 'on-site-1', quantity: 2),
      ]);

      expect(updated, isNotNull);
      expect(updated!.items?.single.name, 'New tap cartridge');
      expect(updated.pricing?.totalMinor, 58764);
      expect(updated.estimatedDurationMinutes, 90);
      expect(controller.jobs.single.version, 3);

      final body = transport.requests.last.body!;
      expect(body['expectedVersion'], 2);
      expect((body['items'] as List).single, {
        'subServiceId': 'on-site-1',
        'quantity': 2,
      });
    },
  );

  test(
    'on-site adjustment surfaces a conflict without losing the job',
    () async {
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
        BookingItemDraft(subServiceId: 'on-site-1', quantity: 1),
      ]);

      expect(updated, isNull);
      expect(controller.actionError, isNotNull);
      expect(controller.jobs.single.version, 2);
    },
  );
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

class _ProviderNotificationTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final now = DateTime.now().toUtc();
    return ApiResponse(
      statusCode: 200,
      body: [
        {
          'id': 'booking-seed-1',
          'title': 'Booking Confirmed & Assigned',
          'body': 'Your booking is confirmed.',
          'category': 'bookings',
          'timestamp': now
              .subtract(const Duration(minutes: 18))
              .toIso8601String(),
          'bookingId': 'booking-seed-1',
          'isRead': false,
        },
        {
          'id': 'offer-seed-1',
          'title': 'Seasonal Home Checkup',
          'body': 'Book a seasonal home checkup.',
          'category': 'offers',
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'isRead': false,
        },
      ],
    );
  }
}

class _ProviderTransport implements ApiTransport {
  _ProviderTransport({
    required this.verified,
    this.itemsConflict = false,
    this.acceptConflict = false,
  });
  final bool verified;
  final bool itemsConflict;
  final bool acceptConflict;
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
    if (request.path.endsWith('/accept')) {
      if (acceptConflict) {
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
            'id': 'request-1',
            'serviceCategoryId': 'plumbing',
            'status': 'ASSIGNED',
            'description': 'Kitchen sink leak',
            'createdAt': '2026-08-14T10:00:00.000Z',
            'version': 5,
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

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
