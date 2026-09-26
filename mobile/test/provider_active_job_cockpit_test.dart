import 'package:fixnow_mobile/design_system/app_colors.dart';
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
  List<BookingItemDraft>? lastSubmittedItems;

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
    final job =
        lastUpdatedJob ??
        CustomerBooking(
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
    lastSubmittedItems = items;
    final updated = job.copyWith(
      items: items
          .map(
            (draft) => BookingLineItem(
              id: draft.id,
              name: draft.name,
              quantity: draft.quantity,
              unitPriceMinor: draft.unitPriceMinor,
            ),
          )
          .toList(growable: false),
      version: job.version + 1,
    );
    return updated;
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
  test('maps provider statuses to user-facing labels', () {
    expect(providerStatusLabel('ASSIGNED'), 'Assigned');
    expect(providerStatusLabel('EN_ROUTE'), 'En route');
    expect(providerStatusLabel('ARRIVED'), 'Arrived');
    expect(providerStatusLabel('IN_PROGRESS'), 'In progress');
    expect(providerStatusLabel('COMPLETED'), 'Completed');
  });

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
      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Navigate opens directions without changing sharing consent', (
      tester,
    ) async {
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

    testWidgets('missing destination never launches default coordinates', (
      tester,
    ) async {
      final job = CustomerBooking(
        id: 'job-1234-5678-90ab',
        serviceCategoryId: 'plumbing',
        status: 'ASSIGNED',
        description: 'Repair sink',
        createdAt: DateTime(2026),
        version: 1,
      );
      await openCockpit(tester, job);
      expect(find.byType(ProviderLiveMap), findsNothing);
      expect(find.text('Customer location unavailable'), findsOneWidget);
      expect(calls, isEmpty);
    });

    for (final failure in ['platform', 'missing', 'false']) {
      testWidgets('shows recoverable error for $failure navigation failure', (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (failure == 'platform') {
                throw PlatformException(code: 'NAVIGATION_ERROR');
              }
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

      expect(find.text('EN ROUTE'), findsOneWidget);
      expect(find.text('Verify PIN & Start Job'), findsOneWidget);

      // Inline 4-digit input feeds the verify flow directly
      await tester.enterText(find.byKey(const Key('otp_hidden_input')), '7362');
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

  testWidgets(
    'ProviderActiveJobCockpitScreen allows opening and updating Adjust Services & Price with BookingLineItem',
    (tester) async {
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
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cockpit_adjust_services_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cockpit_adjust_services_button')));
      await tester.pumpAndSettle();

      expect(find.text('Adjust Services'), findsOneWidget);
      expect(find.text('Pipe Replacement'), findsOneWidget);
      expect(find.text('Update Booking'), findsOneWidget);
    },
  );

  group('Adjust Services sheet', () {
    CustomerBooking adjustableJob() => CustomerBooking(
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

    Future<void> openSheet(WidgetTester tester) async {
      final job = adjustableJob();
      controller.jobs = [job];
      await tester.pumpWidget(
        wrapWidget(
          ProviderActiveJobCockpitScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cockpit_adjust_services_button')));
      await tester.pumpAndSettle();
    }

    // Regression: the sheet painted a light surface while every label was still
    // styled for a dark one, so the title, the line items, the "Customer pays"
    // row and both inputs were white-on-white and effectively invisible.
    testWidgets('renders every label at AA contrast on the sheet surface', (
      tester,
    ) async {
      await openSheet(tester);

      // The two opaque surfaces the sheet actually paints.
      const surfaces = [
        AppColors.surfaceContainerLowest,
        AppColors.surfaceContainerLow,
      ];
      const labels = [
        'Adjust Services',
        'Update the work actually done. The customer sees the revised list and total.',
        'Pipe Replacement',
        'Customer pays (incl. 18% GST)',
        'Add work found on site',
      ];

      for (final label in labels) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: 'missing label: $label');
        final text = tester.widget<Text>(finder);
        final color =
            text.style?.color ??
            DefaultTextStyle.of(tester.element(finder)).style.color;
        expect(color, isNotNull, reason: 'label has no resolved color: $label');
        for (final surface in surfaces) {
          expect(
            _contrastRatio(color!, surface),
            greaterThanOrEqualTo(4.5),
            reason: '"$label" must meet AA on $surface',
          );
        }
      }
    });

    testWidgets('input hints and the close control stay readable', (
      tester,
    ) async {
      await openSheet(tester);

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.decoration)
          .where((decoration) => decoration?.hintText != null)
          .cast<InputDecoration>()
          .toList();
      expect(fields, hasLength(2));

      for (final decoration in fields) {
        // Judged against the field's own fill, which is what the user sees.
        const fill = AppColors.surfaceContainerLowest;
        expect(
          _contrastRatio(decoration.hintStyle!.color!, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'field hint must meet AA on its own fill',
        );
        expect(
          _contrastRatio(decoration.enabledBorder!.borderSide.color, fill),
          greaterThanOrEqualTo(1.4),
          reason: 'field border must be clearly perceptible on its own fill',
        );
      }

      final close = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(
        _contrastRatio(close.color!, AppColors.surfaceContainerLowest),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('adds on-site work and charges 18% GST on the new subtotal', (
      tester,
    ) async {
      await openSheet(tester);

      // 499.00 base + 250.00 on-site = 749.00 subtotal, +18% GST = 883.82.
      expect(find.text('₹588.82'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. New tap cartridge'),
        'New tap cartridge',
      );
      await tester.enterText(find.widgetWithText(TextField, '₹ price'), '250');
      await tester.tap(find.bySemanticsLabel('Add custom service line'));
      await tester.pumpAndSettle();

      expect(find.text('New tap cartridge'), findsOneWidget);
      expect(find.text('₹250 × 1 = ₹250'), findsOneWidget);
      // Subtotal 74900 + 18% = 88382 minor.
      expect(find.text('₹883.82'), findsOneWidget);
    });

    testWidgets('submits the edited line list and closes on success', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. New tap cartridge'),
        'New tap cartridge',
      );
      await tester.enterText(find.widgetWithText(TextField, '₹ price'), '250');
      await tester.tap(find.bySemanticsLabel('Add custom service line'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Booking'));
      await tester.pumpAndSettle();

      final submitted = repository.lastSubmittedItems;
      expect(submitted, isNotNull);
      expect(submitted, hasLength(2));
      expect(submitted!.first.name, 'Pipe Replacement');
      expect(submitted.last.name, 'New tap cartridge');
      expect(submitted.last.unitPriceMinor, 25000);
      expect(find.text('Adjust Services'), findsNothing);
    });

    testWidgets('quantity stepper edits the line and repriced the total', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(
        find.bySemanticsLabel('Increase quantity of Pipe Replacement'),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹499 × 2 = ₹998'), findsOneWidget);
      // 998.00 subtotal + 18% = 1177.64.
      expect(find.text('₹1177.64'), findsOneWidget);
    });
  });
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
