import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/location/map_navigation_launcher.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_jobs_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_navigation_map_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';

class _MockProviderRepository implements ProviderRepository {
  @override
  Future<List<CustomerBooking>> jobs() async => [];

  @override
  Future<ProviderProfile?> profile() async => const ProviderProfile(
        displayName: 'Technician Test',
        bio: 'Professional tech',
        serviceRadiusKm: 25.0,
        baseLatitude: 23.0225,
        baseLongitude: 72.5714,
      );

  @override
  Future<CustomerBooking> updateJobStatus(CustomerBooking job, String status) async =>
      job.copyWith(status: status);

  @override
  Future<CustomerBooking> verifyOtpAndStartJob(CustomerBooking job, String otp) async =>
      job.copyWith(status: 'IN_PROGRESS');

  @override
  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async =>
      job.copyWith(status: 'CANCELLED');

  @override
  Future<CustomerBooking> updateJobItems(
    CustomerBooking job,
    List<BookingItemDraft> items,
  ) async =>
      job;

  @override
  Future<ProviderAvailability> availability() async => throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> categories() async => [];

  @override
  Future<List<ProviderDocument>> documents() async => [];

  @override
  Future<ProviderProfile> saveProfile(ProviderProfile profile) async => profile;

  @override
  Future<ProviderAvailability> setStatus(ProviderAvailability current, String status) async =>
      current;

  @override
  Future<ProviderAvailability> setWeekdaySchedule(
    ProviderAvailability current,
    bool enabled,
  ) async =>
      current;

  @override
  Future<ProviderAvailability> updateSchedule({
    required ProviderAvailability current,
    required List<Map<String, Object?>> weeklyRules,
  }) async =>
      current;

  @override
  Future<ProviderApplication> application() async => throw UnimplementedError();

  @override
  Future<List<ProviderSkill>> skills() async => [];

  @override
  Future<void> addSkill(String categoryId) async {}

  @override
  Future<void> removeSkill(String id) async {}

  @override
  Future<void> acceptBooking(String bookingId) async {}

  @override
  Future<bool> bookingPaymentPaid(String bookingId) async => false;

  @override
  Future<ProviderApplication> submitApplication() async => throw UnimplementedError();

  @override
  Future<CustomerBooking> updateLineItems(
    String bookingId,
    List<Map<String, dynamic>> lineItems,
  ) async => throw UnimplementedError();

  @override
  Future<ProviderProfile> updateLocation(double latitude, double longitude) async =>
      (await profile())!;

  @override
  Future<void> uploadDocument({
    required String type,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) async {}

  @override
  Future<List<ProviderRequest>> availableRequests() async => [];

  @override
  Future<CustomerBooking> acceptRequest(ProviderRequest request) async =>
      throw UnimplementedError();

  @override
  Future<ProviderAcceptTime?> acceptTime() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderController controller;
  late _MockProviderRepository repository;

  setUp(() {
    repository = _MockProviderRepository();
    controller = ProviderController(repository);
  });

  CustomerBooking testJob(String status) => CustomerBooking(
        id: 'job-nav-test-12345',
        serviceCategoryId: 'ac_repair',
        status: status,
        description: 'AC cooling unit servicing in Ahmedabad',
        createdAt: DateTime(2026, 9, 17, 10, 0),
        version: 1,
        locationLatitude: 23.0330,
        locationLongitude: 72.5850,
      );

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.dark,
        home: child,
      );

  group('Provider Navigation & Map System', () {
    testWidgets('ProviderNavigationMapScreen renders route details and navigation actions',
        (tester) async {
      final job = testJob('EN_ROUTE');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrap(
          ProviderNavigationMapScreen(
            job: job,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies the interactive live map widget is on screen
      expect(find.byType(ProviderLiveMap), findsOneWidget);

      // Verifies top title and job category
      expect(find.text('Route to Customer'), findsOneWidget);
      expect(find.textContaining('AC REPAIR'), findsOneWidget);

      // Verifies destination info
      expect(find.text('Destination'), findsOneWidget);
      expect(find.textContaining('23.0330, 72.5850'), findsOneWidget);

      // Verifies the primary Google Maps navigation button
      expect(
        find.text('Start Turn-by-Turn in Google Maps'),
        findsOneWidget,
      );

      // Verifies action buttons for EN_ROUTE state
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });

    testWidgets('ProviderJobsScreen renders Route Map and Navigate buttons for active jobs',
        (tester) async {
      final job = testJob('EN_ROUTE');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrap(
          ProviderJobsScreen(
            controller: controller,
            showHistory: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Route Map'), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);

      // Tapping Route Map pushes ProviderNavigationMapScreen
      await tester.tap(find.text('Route Map'));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderNavigationMapScreen), findsOneWidget);
    });

    testWidgets('ProviderActiveJobCockpitScreen renders Route Map, Navigate, and Transit Preview',
        (tester) async {
      final job = testJob('EN_ROUTE');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrap(
          ProviderActiveJobCockpitScreen(
            job: job,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies Route Map and Navigate buttons in Customer Job Card
      expect(find.text('Route Map'), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);

      // Verifies the in-cockpit Transit Route Preview card (scrolls to it in ListView)
      await tester.scrollUntilVisible(find.text('Transit Route Preview'), 200);
      expect(find.text('Transit Route Preview'), findsOneWidget);
      expect(find.text('Tap to open full route map'), findsOneWidget);

      // Tapping Route Map opens ProviderNavigationMapScreen
      await tester.tap(find.text('Route Map'));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderNavigationMapScreen), findsOneWidget);
    });

    testWidgets('MapNavigationLauncher invokes navigation channel cleanly', (tester) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.fixnow.mobile/navigation'),
        (call) async {
          log.add(call);
          return true;
        },
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => MapNavigationLauncher.launchNavigation(
                context: ctx,
                latitude: 23.0330,
                longitude: 72.5850,
                label: 'Test Destination',
              ),
              child: const Text('Launch Nav'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Nav'));
      await tester.pumpAndSettle();

      expect(log, hasLength(1));
      expect(log.first.method, 'openNavigation');
      expect(log.first.arguments['latitude'], 23.0330);
      expect(log.first.arguments['longitude'], 72.5850);
      expect(log.first.arguments['label'], 'Test Destination');
    });
  });
}
