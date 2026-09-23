import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/notifications/push_api.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:fixnow_mobile/notifications/push_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class FakeTransport implements ApiTransport {
  FakeTransport({this.responses = const []});

  final List<ApiResponse> responses;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (responses.isEmpty) {
      return const ApiResponse(statusCode: 200, body: []);
    }
    return responses.removeAt(0);
  }
}

class FakeGateway implements PushGateway {
  FakeGateway({this.initialized = true, this.permissionGranted = true});

  bool initialized;
  bool permissionGranted;
  String? token = 'f' * 64;

  @override
  Future<bool> ensureInitialized() async => initialized;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<String?> currentToken() async => token;
}

void main() {
  group('PushSettingsCard', () {
    testWidgets('renders Allow Notifications button when permission is denied',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PushSettingsCard(
                initialPermissionStatus: PermissionStatus.denied,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Allow Notifications'), findsOneWidget);
      expect(
        find.textContaining('Allow FixNow to send you instant updates'),
        findsOneWidget,
      );
    });

    testWidgets('renders Active status and preferences when permission is granted',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PushSettingsCard(
                initialPermissionStatus: PermissionStatus.granted,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Booking & Arrival Alerts'), findsOneWidget);
      expect(find.text('Technician Chat'), findsOneWidget);
      expect(find.text('Reminders & Warranties'), findsOneWidget);
      expect(find.text('Manage in device settings'), findsOneWidget);

      // Verify preference switches can be toggled
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));
      await tester.tap(switches.first);
      await tester.pump();
    });

    testWidgets(
        'renders Open System Settings when permission is permanently denied',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PushSettingsCard(
                initialPermissionStatus: PermissionStatus.permanentlyDenied,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Open System Settings'), findsOneWidget);
      expect(
        find.textContaining('Notification permission is blocked in your device settings'),
        findsOneWidget,
      );
    });

    testWidgets(
        'renders registered devices when PushEnrollmentController has devices',
        (tester) async {
      final transport = FakeTransport(
        responses: [
          const ApiResponse(
            statusCode: 200,
            body: [
              {
                'id': 'device-android-1',
                'platform': 'ANDROID',
                'createdAt': '2026-09-01T00:00:00.000Z',
              },
            ],
          ),
          const ApiResponse(
            statusCode: 200,
            body: [
              {
                'id': 'device-android-1',
                'platform': 'ANDROID',
                'createdAt': '2026-09-01T00:00:00.000Z',
              },
            ],
          ),
        ],
      );
      final controller = PushEnrollmentController(
        api: PushApi(transport),
        gateway: FakeGateway(),
        featureEnabled: true,
      );
      await controller.refresh();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PushSettingsCard(
                controller: controller,
                initialPermissionStatus: PermissionStatus.granted,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('REGISTERED DEVICES'), findsOneWidget);
      expect(find.text('Android device'), findsOneWidget);
    });

    testWidgets('tapping Allow Notifications triggers request flow',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PushSettingsCard(
                initialPermissionStatus: PermissionStatus.denied,
                onRequestPermission: () async {
                  requested = true;
                  return PermissionStatus.granted;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final allowButton = find.text('Allow Notifications');
      expect(allowButton, findsOneWidget);
      await tester.tap(allowButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requested, isTrue);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
