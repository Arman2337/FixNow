import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_otp_input_sheet.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProviderRepository implements ProviderRepository {
  CustomerBooking? lastUpdatedJob;
  String? lastUpdatedStatus;
  String? lastVerifiedOtp;

  @override
  Future<List<CustomerBooking>> jobs() async => [];

  @override
  Future<ProviderProfile?> profile() async => null;

  @override
  Future<CustomerBooking> updateJobStatus(CustomerBooking job, String status) async {
    lastUpdatedJob = job;
    lastUpdatedStatus = status;
    return job.copyWith(status: status, version: job.version + 1);
  }

  @override
  Future<CustomerBooking> verifyOtpAndStartJob(CustomerBooking job, String otp) async {
    lastUpdatedJob = job;
    lastVerifiedOtp = otp;
    return job.copyWith(status: 'IN_PROGRESS', version: job.version + 1);
  }

  @override
  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    return job.copyWith(status: 'CANCELLED', version: job.version + 1);
  }

  @override
  Future<ProviderAvailability> availability() async => throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> categories() async => [];

  @override
  Future<List<ProviderDocument>> documents() async => [];

  @override
  Future<ProviderProfile> saveProfile(ProviderProfile profile) async => profile;

  @override
  Future<ProviderAvailability> setStatus(ProviderAvailability current, String status) async => current;

  @override
  Future<ProviderAvailability> setWeekdaySchedule(ProviderAvailability current, bool enabled) async => current;

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
  Future<CustomerBooking> acceptRequest(ProviderRequest request) async => throw UnimplementedError();

  @override
  Future<ProviderApplication> application() async => throw UnimplementedError();

  @override
  Future<ProviderAcceptTime?> acceptTime() async => null;
}

void main() {
  late _FakeProviderRepository repository;
  late ProviderController controller;

  setUp(() {
    repository = _FakeProviderRepository();
    controller = ProviderController(repository);
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
    return MaterialApp(
      theme: AppTheme.dark,
      home: child,
    );
  }

  testWidgets('FixOtpInputSheet renders digit boxes and submits on 4 digits', (tester) async {
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

  testWidgets('ProviderActiveJobCockpitScreen for ASSIGNED job triggers Start Journey', (tester) async {
    final job = createJob('ASSIGNED');
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

    expect(find.text('Job Execution Cockpit'), findsOneWidget);
    expect(find.text('Kitchen sink pipe is leaking heavily.'), findsOneWidget);
    expect(find.text('Start Journey (On My Way)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cockpit_start_journey_button')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdatedStatus, 'EN_ROUTE');
  });

  testWidgets('ProviderActiveJobCockpitScreen for EN_ROUTE job shows Enter Customer Start PIN', (tester) async {
    final job = createJob('EN_ROUTE');
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

    expect(find.text('Arrived at Location'), findsOneWidget);
    expect(find.byKey(const Key('cockpit_verify_otp_button')), findsOneWidget);

    // Tap verify button to open sheet
    await tester.tap(find.byKey(const Key('cockpit_verify_otp_button')));
    await tester.pumpAndSettle();

    expect(find.text('Customer Service Code'), findsOneWidget);

    // Enter 4 digits
    await tester.enterText(find.byKey(const Key('otp_hidden_input')), '7362');
    await tester.pumpAndSettle();

    expect(repository.lastVerifiedOtp, '7362');
  });

  testWidgets('ProviderActiveJobCockpitScreen for IN_PROGRESS job displays photos and complete service', (tester) async {
    final job = createJob('IN_PROGRESS');
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

    expect(find.text('Service in Progress'), findsOneWidget);
    expect(find.byKey(const Key('cockpit_complete_service_button')), findsOneWidget);
    expect(find.text('Add Before & After Photos'), findsOneWidget);
  });

  testWidgets('ProviderActiveJobCockpitScreen for COMPLETED job shows celebration summary', (tester) async {
    final job = createJob('COMPLETED');
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

    expect(find.text('Job Completed'), findsOneWidget);
    expect(find.text('Back to Workspace'), findsOneWidget);
  });
}
