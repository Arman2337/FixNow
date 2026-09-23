import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_otp_input_sheet.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProviderRepository implements ProviderRepository {
  CustomerBooking? lastUpdatedJob;
  String? lastUpdatedStatus;
  String? lastVerifiedOtp;

  @override
  Future<List<CustomerBooking>> jobs() async => [];

  @override
  Future<void> acceptBooking(String bookingId) async {}

  @override
  Future<void> removeSkill(String id) async {}

  @override
  Future<bool> bookingPaymentPaid(String bookingId) async => false;

  @override
  Future<ProviderProfile> updateLocation(double lat, double lng) async {
    return const ProviderProfile(
      displayName: 'Test',
      bio: 'Test Bio',
      serviceRadiusKm: 10,
      baseLatitude: 0,
      baseLongitude: 0,
    );
  }

  @override
  Future<ProviderProfile?> profile() async => null;

  @override
  Future<CustomerBooking> updateJobStatus(
    CustomerBooking job,
    String status,
  ) async {
    lastUpdatedJob = job;
    lastUpdatedStatus = status;
    return job.copyWith(status: status, version: job.version + 1);
  }

  @override
  Future<CustomerBooking> verifyOtpAndStartJob(
    CustomerBooking job,
    String otp,
  ) async {
    lastUpdatedJob = job;
    lastVerifiedOtp = otp;
    return job.copyWith(status: 'IN_PROGRESS', version: job.version + 1);
  }

  @override
  Future<CustomerBooking> updateLineItems(
    String bookingId,
    List<Map<String, dynamic>> lineItems,
  ) async {
    final job = lastUpdatedJob ?? CustomerBooking(
      id: bookingId,
      serviceCategoryId: 'plumbing',
      status: 'IN_PROGRESS',
      description: '',
      createdAt: DateTime.now(),
      version: 1,
    );
    return job.copyWith(version: job.version + 1);
  }

  @override
  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    return job.copyWith(status: 'CANCELLED', version: job.version + 1);
  }

  @override
  Future<CustomerBooking> updateJobItems(
    CustomerBooking job,
    List<BookingItemDraft> items,
  ) async {
    lastUpdatedJob = job;
    return job.copyWith(items: null, version: job.version + 1);
  }

  @override
  Future<ProviderAvailability> availability() async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> categories() async => [];

  @override
  Future<List<ProviderDocument>> documents() async => [];

  @override
  Future<ProviderProfile> saveProfile(ProviderProfile profile) async => profile;

  @override
  Future<ProviderAvailability> setStatus(
    ProviderAvailability current,
    String status,
  ) async => current;

  @override
  Future<ProviderAvailability> setWeekdaySchedule(
    ProviderAvailability current,
    bool enabled,
  ) async => current;

  @override
  Future<ProviderAvailability> updateSchedule({
    required ProviderAvailability current,
    required List<Map<String, Object?>> weeklyRules,
  }) async => current;

  @override
  Future<List<ProviderSkill>> skills() async => [];

  @override
  Future<void> addSkill(String serviceCategoryId) async {}

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
  Future<ProviderApplication> application() async => throw UnimplementedError();

  @override
  Future<ProviderAcceptTime?> acceptTime() async => null;

  @override
  Future<ProviderApplication> submitApplication() async =>
      throw UnimplementedError();
}

void main() {
  late _FakeProviderRepository repository;
  late ProviderController controller;

  setUp(() {
    repository = _FakeProviderRepository();
    controller = ProviderController(repository);
  });

  tearDown(() {
    try {
      controller.dispose();
    } catch (_) {}
  });

  CustomerBooking createJob(String status) {
    return CustomerBooking(
      id: 'job-1234-5678-90ab',
      serviceCategoryId: 'plumbing',
      status: status,
      description: 'Kitchen sink pipe is leaking heavily.',
      createdAt: DateTime.now(),
      version: 1,
      locationLatitude: 18.9220,
      locationLongitude: 72.8347,
    );
  }

  Widget wrapWidget(Widget child) {
    return MaterialApp(theme: AppTheme.dark, home: child);
  }

  group('cockpit navigation', () {
    const channel = MethodChannel('com.fixnow.mobile/navigation');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> openCockpit(WidgetTester tester, CustomerBooking job) async {
      controller.jobs = [job];
      await tester.pumpWidget(wrapWidget(
        ProviderActiveJobCockpitScreen(job: job, controller: controller),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Navigate opens directions without changing sharing consent', (tester) async {
      await openCockpit(tester, createJob('ASSIGNED'));
      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'openNavigation');
      expect(calls.single.arguments['latitude'], 18.9220);
      expect(calls.single.arguments['longitude'], 72.8347);
      expect(controller.locationSharing, isEmpty);
    });

    testWidgets('preview does not invent a provider position', (tester) async {
      await openCockpit(tester, createJob('ASSIGNED'));
      final map = tester.widget<ProviderLiveMap>(find.byType(ProviderLiveMap));
      expect(map.providerLocation, isNull);
      expect(map.customerLocation?.latitude, 18.9220);
    });

    testWidgets('map preview also opens directions', (tester) async {
      await openCockpit(tester, createJob('ASSIGNED'));
      await tester.tapAt(tester.getCenter(find.byType(ProviderLiveMap)));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
    });

    testWidgets('missing destination never launches default coordinates', (tester) async {
      final job = CustomerBooking(
        id: 'job-1234-5678-90ab', serviceCategoryId: 'plumbing',
        status: 'ASSIGNED', description: 'Repair sink', createdAt: DateTime(2026), version: 1,
      );
      await openCockpit(tester, job);
      expect(find.byType(ProviderLiveMap), findsNothing);
      expect(find.text('Customer location unavailable'), findsOneWidget);
      expect(calls, isEmpty);
    });

    for (final failure in ['platform', 'missing', 'false']) {
      testWidgets('shows recoverable error for $failure navigation failure', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (failure == 'platform') throw PlatformException(code: 'NAVIGATION_ERROR');
              if (failure == 'missing') throw MissingPluginException();
              return false;
            });
        await openCockpit(tester, createJob('ASSIGNED'));
        await tester.tap(find.text('Navigate'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Could not open maps'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('FixOtpInputSheet renders digit boxes and submits on 4 digits', (
    tester,
  ) async {
    String? submittedCode;

    await tester.pumpWidget(
      wrapWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              submittedCode = await FixOtpInputSheet.show(context);
            },
            child: const Text('Open OTP Sheet'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open OTP Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Service Code'), findsOneWidget);
    expect(find.byKey(const Key('otp_verify_button')), findsOneWidget);

    // Enter 4 digits into hidden field
    await tester.enterText(find.byKey(const Key('otp_hidden_input')), '4821');
    await tester.pumpAndSettle();

    expect(submittedCode, '4821');
  });

  testWidgets(
    'ProviderActiveJobCockpitScreen for ASSIGNED job triggers Start Journey',
    (tester) async {
      final job = createJob('ASSIGNED');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Job Cockpit'), findsOneWidget);
      expect(find.text('Start Journey (On My Way)'), findsOneWidget);

      await tester.tap(find.text('Start Journey (On My Way)'));
      await tester.pumpAndSettle();

      expect(repository.lastUpdatedStatus, 'EN_ROUTE');
      controller.dispose();
    },
  );

  testWidgets(
    'ProviderActiveJobCockpitScreen for EN_ROUTE job shows Enter Customer Start PIN',
    (tester) async {
      final job = createJob('EN_ROUTE');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ARRIVED AT LOCATION'), findsOneWidget);
      expect(find.text('Verify PIN & Start Job'), findsOneWidget);

      // Inline 4-digit input feeds the verify flow directly
      await tester.enterText(
        find.byKey(const Key('otp_hidden_input')),
        '7362',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify PIN & Start Job'));
      await tester.pumpAndSettle();

      expect(repository.lastVerifiedOtp, '7362');
    },
  );

  testWidgets(
    'ProviderActiveJobCockpitScreen for IN_PROGRESS job displays photos and complete service',
    (tester) async {
      final job = createJob('IN_PROGRESS');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SERVICE IN PROGRESS'), findsOneWidget);
      expect(
        find.byKey(const Key('cockpit_complete_service_button')),
        findsOneWidget,
      );
      expect(find.text('Job Proof & Materials'), findsOneWidget);
    },
  );

  testWidgets(
    'ProviderActiveJobCockpitScreen for COMPLETED job shows celebration summary',
    (tester) async {
      final job = createJob('COMPLETED');
      controller.jobs = [job];

      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JOB COMPLETED'), findsOneWidget);
      expect(find.text('Job Successfully Completed'), findsOneWidget);
    },
  );

  testWidgets('ProviderActiveJobCockpitScreen allows opening and updating Adjust Services & Price with BookingLineItem', (tester) async {
    final job = CustomerBooking(
      id: 'job-1234-5678-90ab',
      serviceCategoryId: 'plumbing',
      status: 'IN_PROGRESS',
      description: 'Kitchen sink pipe is leaking heavily.',
      createdAt: DateTime.now(),
      version: 1,
      locationLatitude: 18.9220,
      locationLongitude: 72.8347,
      items: const [
        BookingLineItem(
          id: 'item-1',
          name: 'Pipe Replacement',
          quantity: 1,
          unitPriceMinor: 49900,
        ),
      ],
    );
    controller.jobs = [job];

    await tester.pumpWidget(
      wrapWidget(
        ProviderActiveJobCockpitScreen(
          job: job,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cockpit_adjust_services_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cockpit_adjust_services_button')));
    await tester.pumpAndSettle();

    expect(find.text('Adjust Services'), findsOneWidget);
    expect(find.text('Pipe Replacement'), findsOneWidget);
    expect(find.text('Update Booking'), findsOneWidget);
  });
}
