import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_screen.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/auth/verification_screen.dart';
import 'package:fixnow_mobile/auth/welcome_screen.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/call/call_screen.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/emergency/emergency_confirm_screen.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_screen.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_incoming_request_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_jobs_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_navigation_map_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_profile_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:fixnow_mobile/features/services/sub_service_catalog_screen.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';
import 'package:fixnow_mobile/features/support/complaint.dart';
import 'package:fixnow_mobile/features/support/complaint_list_screen.dart';
import 'package:fixnow_mobile/features/support/customer_help_screen.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_screen.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_source.dart';
import 'support/test_address_repository.dart';

class CrawlerTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path.contains('service-categories')) {
      return const ApiResponse(
        statusCode: 200,
        body: [
          {
            'id': 'cat-plumbing',
            'name': 'Plumbing Services',
            'slug': 'plumbing',
            'description': 'Pipe repair, taps and drainage',
            'iconName': 'plumbing',
            'pricing': {'amountMinor': 49900, 'currency': 'INR'},
          },
        ],
      );
    }
    if (request.path.contains('sub-services')) {
      return const ApiResponse(
        statusCode: 200,
        body: [
          {
            'id': 'sub-tap',
            'name': 'Tap Repair',
            'description': 'Fix leaking taps and washers',
            'unitPriceMinor': 19900,
            'durationMinutes': 30,
            'categoryId': 'cat-plumbing',
          },
        ],
      );
    }
    if (request.path.contains('bookings')) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'bookings': [
            {
              'id': 'booking-crawler-1',
              'serviceCategoryId': 'cat-plumbing',
              'status': 'ASSIGNED',
              'description': 'Sink leak repair in kitchen',
              'createdAt': '2026-10-14T10:00:00.000Z',
              'version': 1,
              'providerName': 'Rajesh Kumar',
              'customerPhone': '+919876543210',
              'providerPhone': '+919876543211',
              'locationLatitude': 23.0225,
              'locationLongitude': 72.5714,
            },
          ],
          'nextCursor': null,
        },
      );
    }
    if (request.path.contains('notifications')) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'notifications': [
            {
              'id': 'notif-1',
              'title': 'Booking Confirmed',
              'body': 'Your plumbing service is scheduled',
              'type': 'BOOKING_UPDATE',
              'timestamp': '2026-10-14T10:00:00.000Z',
              'isRead': false,
              'data': {'bookingId': 'booking-crawler-1'},
            },
          ],
          'unreadCount': 1,
        },
      );
    }
    if (request.path.contains('provider-applications')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'status': 'approved', 'decisionReason': null},
      );
    }
    if (request.path.contains('provider-profile')) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'displayName': 'Verified Partner',
          'bio': 'Certified expert technician',
          'serviceRadiusKm': 25.0,
          'baseLatitude': 23.0225,
          'baseLongitude': 72.5714,
        },
      );
    }
    if (request.path.contains('earnings')) {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'grossMinor': 2500000,
          'refundedMinor': 150000,
          'netMinor': 2350000,
          'paidOrderCount': 42,
          'note': 'Completed customer payments, less recorded refunds.',
        },
      );
    }
    return const ApiResponse(statusCode: 200, body: <String, dynamic>{});
  }
}

class FakeSessionStore implements AuthSessionStore {
  FakeSessionStore(this.session);
  AuthSession? session;
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class FakeLocationGateway implements LocationPermissionGateway {
  const FakeLocationGateway(this.state);
  final LocationPermissionState state;

  @override
  Future<LocationPermissionState> check() async => state;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<LocationPermissionState> request() async => state;
}

class FakeComplaintsRepo implements ComplaintsRepository {
  @override
  Future<List<Complaint>> listComplaints() async => [
    Complaint(
      id: 'complaint-1',
      bookingId: 'booking-crawler-1',
      submitterId: 'user-1',
      targetRole: 'provider',
      targetId: 'prov-1',
      category: 'SERVICE_QUALITY',
      description: 'Technician arrived 10 minutes late.',
      status: 'OPEN',
      createdAt: DateTime.utc(2026, 10, 14, 11),
      updatedAt: DateTime.utc(2026, 10, 14, 11),
    ),
  ];

  @override
  Future<Complaint> getComplaint(String id) async =>
      (await listComplaints()).first;

  @override
  Future<Complaint> addEvidence(
    String id, {
    required String fileUrl,
    required String fileType,
    String? description,
  }) async => (await listComplaints()).first;

  @override
  Future<Complaint> requestCallback(String id) async =>
      (await listComplaints()).first;

  @override
  Future<Complaint> submitComplaint({
    String? bookingId,
    required String targetRole,
    String? targetId,
    required String category,
    required String description,
  }) async => (await listComplaints()).first;
}

void main() {
  setUp(createTestAddressRepository);
  TestWidgetsFlutterBinding.ensureInitialized();

  final transport = CrawlerTransport();
  final authController = AuthController(
    api: AuthApi(transport),
    store: FakeSessionStore(
      AuthSession(
        userId: 'crawler-user-1',
        accessToken: 'crawler-access-token',
        refreshToken: 'crawler-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
      ),
    ),
  );

  final sampleCategory = const ServiceCategory(
    id: 'cat-plumbing',
    name: 'Plumbing Services',
    slug: 'plumbing',
    description: 'Pipe repairs and fixtures',
    iconName: 'plumbing',
    pricing: ServiceCategoryPricing(amountMinor: 49900, currency: 'INR'),
  );

  final sampleBooking = CustomerBooking(
    id: 'booking-crawler-1',
    serviceCategoryId: 'cat-plumbing',
    status: 'ASSIGNED',
    description: 'Kitchen sink pipe repair',
    createdAt: DateTime.utc(2026, 10, 14, 10),
    version: 1,
    customerPhone: '+919876543210',
    providerPhone: '+919876543211',
    providerName: 'Vikram Singh',
    providerRating: 4.85,
    providerJobsCount: 120,
    locationLatitude: 23.0225,
    locationLongitude: 72.5714,
    pricing: const BookingPricing(
      subtotalMinor: 49900,
      gstMinor: 8982,
      totalMinor: 58882,
      currency: 'INR',
    ),
  );

  final sampleInvoice = Invoice(
    invoiceNumber: 'INV-2026-0001',
    issuedAt: DateTime.utc(2026, 10, 14, 12),
    amountLabel: '₹588.82',
    statusLabel: 'Paid',
    amountMinor: 58882,
    currency: 'INR',
    bookingId: 'booking-crawler-1',
    serviceName: 'Plumbing Service',
  );

  final Map<String, Widget Function()> screens = {
    'WelcomeScreen': () => WelcomeScreen(onContinue: (context, role) {}),
    'AuthScreen': () => AuthScreen(
      controller: authController,
      role: AccountRole.customer,
      initialRegister: false,
      onBack: () {},
    ),
    'VerificationScreen': () => VerificationScreen(
      controller: authController,
      localOtpBypassEnabled: true,
    ),
    'ServiceDiscoveryScreen': () => ServiceDiscoveryScreen(
      controller: ServiceDiscoveryController(
        ApiServiceCategoryRepository(transport),
        SubServiceRepository(transport),
      ),
      locationController: LocationConsentController(
        const FakeLocationGateway(LocationPermissionState.granted),
      ),
    ),
    'SubServiceCatalogScreen': () =>
        SubServiceCatalogScreen(category: sampleCategory, api: transport),
    'ServiceRequestScreen': () => ServiceRequestScreen(
      category: sampleCategory,
      controller: BookingController(
        BookingRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'CustomerBookingsScreen': () => CustomerBookingsScreen(
      controller: BookingController(
        BookingRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'BookingDetailScreen': () => BookingDetailScreen(booking: sampleBooking),
    'BookingTrackingScreen': () => BookingTrackingScreen(
      controller: BookingTrackingController(
        bookingId: 'booking-crawler-1',
        source: ApiBookingTrackingSource(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'BookingChatScreen': () => BookingChatScreen(
      controller: ChatController(
        bookingId: 'booking-crawler-1',
        repository: HttpChatRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
          currentUserId: () => 'crawler-user-1',
        ),
        currentUserId: 'crawler-user-1',
      ),
    ),
    'CallScreen': () => const CallScreen(
      oppositePartyName: 'Vikram Singh',
      oppositePartyRole: 'Service Specialist',
      phoneNumber: '+919876543211',
      bookingId: 'booking-crawler-1',
    ),
    'ProblemDiagnosisScreen': () => ProblemDiagnosisScreen(
      controller: ProblemDiagnosisController(
        ProblemAnalysisRepository(transport),
      ),
      categories: [sampleCategory],
    ),
    'CustomerHelpScreen (Customer Mode)': () => CustomerHelpScreen(
      controller: ComplaintsController(FakeComplaintsRepo()),
      isProvider: false,
    ),
    'CustomerHelpScreen (Provider Mode)': () => CustomerHelpScreen(
      controller: ComplaintsController(FakeComplaintsRepo()),
      isProvider: true,
    ),
    'ComplaintListScreen': () => ComplaintListScreen(
      controller: ComplaintsController(FakeComplaintsRepo()),
    ),
    'SubmitComplaintScreen': () => SubmitComplaintScreen(
      controller: ComplaintsController(FakeComplaintsRepo()),
      targetRole: 'provider',
      bookingId: 'booking-crawler-1',
    ),
    'NotificationCenterScreen': () => NotificationCenterScreen(
      controller: NotificationController(
        NotificationRepository(api: transport),
      ),
    ),
    'EmergencyConfirmScreen': () => EmergencyConfirmScreen(
      categories: [sampleCategory],
      repository: EmergencyRepository(transport),
    ),
    'InvoiceScreen': () => InvoiceScreen(
      repository: InvoiceRepository(transport),
      bookingId: 'booking-crawler-1',
      initialInvoice: sampleInvoice,
    ),
    'CustomerProfileScreen': () => CustomerProfileScreen(
      controller: CustomerProfileController(
        ApiCustomerProfileRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'ProviderHomeScreen': () => ProviderHomeScreen(
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'ProviderJobsScreen': () => ProviderJobsScreen(
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
      showHistory: false,
    ),
    'ProviderActiveJobCockpitScreen': () => ProviderActiveJobCockpitScreen(
      job: sampleBooking,
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'ProviderNavigationMapScreen': () => ProviderNavigationMapScreen(
      job: sampleBooking,
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'ProviderIncomingRequestScreen': () => ProviderIncomingRequestScreen(
      requestData: {
        'bookingId': 'booking-crawler-1',
        'serviceCategoryId': 'cat-plumbing',
        'categoryName': 'Plumbing Services',
        'description': 'Kitchen sink pipe repair',
        'estimatedAmountMinor': 49900,
        'durationMinutes': 45,
        'distanceKm': 2.3,
        'customerName': 'Asha Patel',
        'address': 'Flat 402, Shivalik Residency, Ahmedabad',
      },
      providerController: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
    ),
    'ProviderEarningsScreen': () => ProviderEarningsScreen(
      repository: ProviderEarningsRepository(transport),
    ),
    'ProviderOnboardingScreen': () => ProviderOnboardingScreen(
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
      onSignOut: () {},
    ),
    'ProviderProfileScreen': () => ProviderProfileScreen(
      controller: ProviderController(
        ProviderRepository(
          api: transport,
          accessToken: () async => 'crawler-token',
        ),
      ),
      onSignOut: () {},
    ),
  };

  final viewports = [
    (
      name: 'Narrow Phone (320x640)',
      size: const Size(320, 640),
      insets: FakeViewPadding.zero,
    ),
    (
      name: 'Keyboard Open (390x844 + 300 bottom inset)',
      size: const Size(390, 844),
      insets: const FakeViewPadding(bottom: 300),
    ),
  ];

  for (final vp in viewports) {
    group('Viewport: ${vp.name}', () {
      for (final entry in screens.entries) {
        testWidgets('crawls and verifies zero layout overflow on ${entry.key}', (
          tester,
        ) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          tester.view.viewInsets = vp.insets;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewInsets();
          });

          final List<FlutterErrorDetails> errorDetails = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errorDetails.add(details);
          };

          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(body: entry.value()),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));

            // Check for RenderFlex overflow on mount
            for (final err in errorDetails) {
              if (err.exceptionAsString().contains('overflowed') ||
                  err.exceptionAsString().contains('RenderFlex')) {
                debugPrint('FOUND MOUNT OVERFLOW in ${entry.key}: $err');
              }
            }

            // Discover interactive widgets
            final interactiveTypes = [
              ElevatedButton,
              FilledButton,
              OutlinedButton,
              TextButton,
              IconButton,
              Switch,
              ChoiceChip,
              FilterChip,
              InkWell,
            ];

            for (final type in interactiveTypes) {
              final elements = find.byType(type).evaluate().toList();
              for (final elem in elements) {
                try {
                  if (elem.renderObject != null &&
                      elem.renderObject!.attached) {
                    await tester.tap(
                      find.byWidget(elem.widget),
                      warnIfMissed: false,
                    );
                    await tester.pump(const Duration(milliseconds: 150));
                  }
                } catch (_) {
                  // Tap miss or already dismissed
                }

                // Cleanly dismiss any open Dialog or ModalBarrier
                final barrierFinder = find.byType(ModalBarrier);
                if (barrierFinder.evaluate().isNotEmpty) {
                  final nav = Navigator.maybeOf(
                    tester.element(barrierFinder.last),
                  );
                  if (nav != null && nav.canPop()) {
                    nav.pop();
                  }
                }
              }
            }

            for (final err in errorDetails) {
              if (err.exceptionAsString().contains('overflowed') ||
                  err.exceptionAsString().contains('RenderFlex')) {
                debugPrint(
                  'FOUND INTERACTION OVERFLOW in ${entry.key}: ${err.exceptionAsString()}',
                );
              }
            }
          } finally {
            FlutterError.onError = originalOnError;
          }

          for (final err in errorDetails) {
            if (err.exceptionAsString().contains('overflowed') ||
                err.exceptionAsString().contains('RenderFlex')) {
              fail(
                'Layout overflow on ${entry.key} at ${vp.name}:\n${err.exceptionAsString()}',
              );
            }
          }
        });
      }
    });
  }
}
