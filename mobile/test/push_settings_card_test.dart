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

class FailingRegistrationTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method == ApiMethod.put) {
      throw const ApiException(
        ApiFailureKind.server,
        'Registration unavailable.',
      );
    }
    return const ApiResponse(statusCode: 200, body: []);
  }
}

void main() {
  group('PushSettingsCard', () {
    testWidgets(
      'renders Allow Notifications button when permission is denied',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
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
      },
    );

    testWidgets(
      'renders Active status and preferences when permission is granted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
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
        expect(find.text('Permission allowed'), findsOneWidget);
        expect(
          find.textContaining(
            'Per-category notification preferences are not available yet',
          ),
          findsOneWidget,
        );

        expect(find.text('Manage in device settings'), findsOneWidget);

        expect(find.byType(Switch), findsNothing);
      },
    );

    testWidgets(
      'renders Open System Settings when permission is permanently denied',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
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
          find.textContaining(
            'Notification permission is blocked in your device settings',
          ),
          findsOneWidget,
        );
      },
    );

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
            theme: AppTheme.light,
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
      },
    );

    testWidgets(
      'permission plugin failure never grants permission and can be retried',
      (tester) async {
        var attempts = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PushSettingsCard(
                  initialPermissionStatus: PermissionStatus.denied,
                  onRequestPermission: () async {
                    attempts++;
                    if (attempts == 1) {
                      throw StateError('Permission plugin unavailable');
                    }
                    return PermissionStatus.granted;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Allow Notifications'));
        await tester.pumpAndSettle();
        expect(find.text('Permission allowed'), findsNothing);
        expect(
          find.textContaining('Could not enable notifications.'),
          findsOneWidget,
        );
        expect(find.text('Allow Notifications'), findsOneWidget);
        await tester.tap(find.text('Allow Notifications'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text('Permission allowed'), findsOneWidget);
        expect(
          find.textContaining('push registration is unavailable in this build'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Notification permission is allowed and push registration completed.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'registration failure preserves honest permission state and offers retry',
      (tester) async {
        final controller = PushEnrollmentController(
          api: PushApi(FailingRegistrationTransport()),
          gateway: FakeGateway(),
          featureEnabled: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PushSettingsCard(
                  controller: controller,
                  initialPermissionStatus: PermissionStatus.denied,
                  onRequestPermission: () async => PermissionStatus.granted,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow Notifications'));
        await tester.pumpAndSettle();
        expect(controller.status, PushEnrollmentStatus.error);
        expect(find.text('Permission allowed'), findsOneWidget);
        expect(
          find.textContaining('push registration could not be completed'),
          findsOneWidget,
        );
        expect(find.text('Retry push registration'), findsOneWidget);
        expect(
          find.text(
            'Notification permission is allowed and push registration completed.',
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets('tapping Allow Notifications triggers request flow', (
      tester,
    ) async {
      var requested = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
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
      expect(find.text('Permission allowed'), findsOneWidget);
    });
  });
}
