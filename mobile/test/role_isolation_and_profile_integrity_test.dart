import 'package:fixnow_mobile/app/app.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/features/call/call_screen.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_jobs_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_profile_screen.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pump_idle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role Isolation & Profile Integrity', () {
    testWidgets(
      'Verified Provider navigation isolates provider tabs from customer screens & KYC wizard',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildApp(role: AccountRole.verifiedProvider),
        );
        await tester.pumpIdle();

        // 1. Tab 0: Provider Home Dashboard
        expect(find.byType(ProviderHomeScreen), findsOneWidget);
        expect(find.byType(ServiceDiscoveryScreen), findsNothing);
        expect(find.text('Book Now'), findsNothing);

        // 2. Tab 1: Active Job
        await tester.tap(find.text('Active Job'));
        await tester.pumpIdle();
        expect(find.byType(CustomerBookingsScreen), findsNothing);
        expect(find.byType(ProviderJobsScreen), findsOneWidget);
        expect(find.textContaining('Assigned Jobs'), findsOneWidget);

        // 3. Tab 2: History
        await tester.tap(find.text('History'));
        await tester.pumpIdle();
        expect(find.byType(CustomerBookingsScreen), findsNothing);
        expect(find.byType(ProviderJobsScreen), findsOneWidget);

        // 4. Tab 3: Provider Profile & Operations Hub (NOT 4-step KYC applicant wizard!)
        await tester.tap(find.text('Profile'));
        await tester.pumpIdle();
        expect(find.byType(ProviderProfileScreen), findsOneWidget);
        expect(find.text('Provider Profile & Hub'), findsOneWidget);
        expect(find.text('Working Hours & Shifts'), findsOneWidget);
        expect(find.text('Service Dispatch Radius'), findsOneWidget);
        expect(find.text('Sign Out of Partner Account'), findsOneWidget);
        // KYC applicant wizard step 1 must NOT appear on verified profile tab
        expect(find.text('Step 1 of 4'), findsNothing);
        expect(find.text('Upload Aadhaar Document'), findsNothing);

        // Assert zero hardcoded external network images in provider tree
        for (final element in find.byType(Image).evaluate()) {
          final widget = element.widget as Image;
          if (widget.image is NetworkImage) {
            final netImg = widget.image as NetworkImage;
            expect(netImg.url.contains('googleusercontent'), isFalse);
            expect(netImg.url.contains('pravatar'), isFalse);
            expect(netImg.url.contains('unsplash'), isFalse);
            expect(netImg.url.contains('picsum'), isFalse);
          }
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pumpIdle();
      },
    );

    testWidgets(
      'Customer navigation isolates customer tabs from provider screens',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildApp(role: AccountRole.customer),
        );
        await tester.pumpIdle();

        // 1. Tab 0: Service Discovery (Customer Home)
        expect(find.byType(ServiceDiscoveryScreen), findsOneWidget);
        expect(find.byType(ProviderHomeScreen), findsNothing);
        expect(find.text('Accept Job'), findsNothing);

        // 2. Tab 1: Customer Bookings
        await tester.tap(find.text('Bookings'));
        await tester.pumpIdle();
        expect(find.byType(CustomerBookingsScreen), findsOneWidget);
        expect(find.byType(ProviderJobsScreen), findsNothing);

        // 3. Tab 2: Customer Help
        await tester.tap(find.text('Help'));
        await tester.pumpIdle();
        expect(find.text('Help & Knowledge Base'), findsOneWidget);
        expect(find.byType(ProviderJobsScreen), findsNothing);

        // 4. Tab 3: Customer Profile
        await tester.tap(find.text('Profile'));
        await tester.pumpIdle();
        expect(find.byType(ProviderProfileScreen), findsNothing);
        expect(find.text('Working Hours & Shifts'), findsNothing);
        expect(find.text('Service Dispatch Radius'), findsNothing);

        // Assert zero hardcoded external network images in customer tree
        for (final element in find.byType(Image).evaluate()) {
          final widget = element.widget as Image;
          if (widget.image is NetworkImage) {
            final netImg = widget.image as NetworkImage;
            expect(netImg.url.contains('googleusercontent'), isFalse);
            expect(netImg.url.contains('pravatar'), isFalse);
            expect(netImg.url.contains('unsplash'), isFalse);
            expect(netImg.url.contains('picsum'), isFalse);
          }
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pumpIdle();
      },
    );

    testWidgets(
      'CallScreen dynamically reflects opposite party identity and role isolation',
      (tester) async {
        // Test Customer calling Specialist: callee role is Service Specialist
        await tester.pumpWidget(
          const MaterialApp(
            home: CallScreen(
              oppositePartyName: 'Ramesh Sharma',
              oppositePartyRole: 'Service Specialist',
              bookingId: 'booking-999',
              isProvider: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ramesh Sharma'), findsOneWidget);
        expect(find.text('SERVICE SPECIALIST'), findsOneWidget);
        // Specialist receives the verified green badge
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

        // Test Provider calling Customer: callee role is Customer
        await tester.pumpWidget(
          const MaterialApp(
            home: CallScreen(
              oppositePartyName: 'Ananya Verma',
              oppositePartyRole: 'Customer',
              bookingId: 'booking-999',
              isProvider: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ananya Verma'), findsOneWidget);
        expect(find.text('CUSTOMER'), findsOneWidget);
        // Customer does NOT receive verified technician badge
        expect(find.byIcon(Icons.verified_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'BookingChatScreen isolates provider vs customer header presentation',
      (tester) async {
        final mockRepo = _MockChatRepo();

        // 1. Customer perspective chatting with Provider
        final customerChatCtrl = ChatController(
          bookingId: 'booking-888',
          repository: mockRepo,
          isProvider: false,
        );
        addTearDown(customerChatCtrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: BookingChatScreen(
              controller: customerChatCtrl,
              providerName: 'Vikram Electricals',
              onCallPressed: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vikram Electricals'), findsOneWidget);
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
        expect(find.byTooltip('Call Specialist'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // 2. Provider perspective chatting with Customer
        final providerChatCtrl = ChatController(
          bookingId: 'booking-888',
          repository: mockRepo,
          isProvider: true,
        );
        addTearDown(providerChatCtrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: BookingChatScreen(
              controller: providerChatCtrl,
              customerName: 'Priya Mehta',
              onCallPressed: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Priya Mehta'), findsOneWidget);
        // Customer must NOT have verified specialist badge
        expect(find.byIcon(Icons.verified_rounded), findsNothing);
        expect(find.byTooltip('Call Customer'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}

FixNowApp _buildApp({required AccountRole role}) {
  return FixNowApp(
    environment: AppEnvironment.development,
    apiTransport: _MultiRoleTransport(),
    sessionStore: _RoleSessionStore(role: role),
    locationGateway: _StubLocationGateway(),
    snapshotStore: MemorySnapshotStore(),
  );
}

class _MockChatRepo implements ChatRepository {
  @override
  String? get currentUserId => 'user-1';

  @override
  Future<({List<ChatMessage> messages, bool canSend})> fetchMessages(
    String bookingId,
  ) async {
    return (messages: <ChatMessage>[], canSend: true);
  }

  @override
  Future<ChatMessage> sendMessage(
    String bookingId,
    String messageText, {
    String? clientMessageId,
  }) async {
    return ChatMessage(
      id: 'msg-1',
      bookingId: bookingId,
      senderUserId: 'user-1',
      senderRole: 'CUSTOMER',
      messageText: messageText,
      createdAt: DateTime.now(),
      isMe: true,
    );
  }
}

class _RoleSessionStore implements AuthSessionStore {
  _RoleSessionStore({required this.role});
  final AccountRole role;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => AuthSession(
        userId: role == AccountRole.verifiedProvider ? 'pro-1' : 'cust-1',
        accessToken: 'valid-test-token',
        refreshToken: 'valid-test-refresh',
        role: role,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
      );

  @override
  Future<void> write(AuthSession session) async {}
}

class _StubLocationGateway implements LocationPermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;
}

class _MultiRoleTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final path = request.path;

    if (path.startsWith('service-categories')) {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (path.startsWith('bookings?')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    if (path == 'provider-applications/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {'status': 'approved'},
      );
    }
    if (path == 'provider-profile/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'displayName': 'Suresh Verma',
          'bio': 'Certified FixNow Specialist',
          'serviceRadiusKm': 12.0,
          'baseLatitude': 12.9716,
          'baseLongitude': 77.5946,
          'stats': {
            'rating': 4.9,
            'reviewCount': 42,
            'completedJobs': 88,
            'earningsMinor': 2450000,
            'acceptanceRate': 96,
          },
        },
      );
    }
    if (path == 'provider-skills/me') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (path == 'provider-documents/me') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (path == 'provider-availability/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'status': 'online',
          'version': 1,
          'timeZone': 'Asia/Kolkata',
          'weeklyRules': [],
        },
      );
    }
    if (path == 'providers/me/jobs') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (path == 'providers/me/requests') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (path == 'trust/my-accept-time') {
      return const ApiResponse(statusCode: 404, body: null);
    }

    return const ApiResponse(statusCode: 200, body: <String, Object?>{});
  }
}
