import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport implements ApiTransport {
  Future<ApiResponse> Function(ApiRequest) handler = (_) async =>
      const ApiResponse(statusCode: 200, body: null);
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) {
    requests.add(request);
    return handler(request);
  }
}

Map<String, Object?> call(String status) => {
  'id': 'call-1',
  'bookingId': 'booking-1',
  'status': status,
  'callerUserId': 'user-1',
  'calleeUserId': 'user-2',
  'startedAt': '2026-10-21T00:00:00Z',
};

Map<String, Object?> notification(String id) => {
  'id': id,
  'title': id,
  'body': 'Booking update',
  'category': 'bookings',
  'timestamp': '2026-10-21T00:00:00Z',
  'isRead': false,
};

void main() {
  test(
    'call lifecycle awaits server state and rejects failed active-call reads',
    () async {
      final transport = _Transport();
      transport.handler = (request) async {
        if (request.path.endsWith('initiate')) {
          return ApiResponse(statusCode: 201, body: {'call': call('RINGING')});
        }
        if (request.path.endsWith('answer')) {
          return ApiResponse(statusCode: 200, body: call('CONNECTED'));
        }
        if (request.path.endsWith('reject')) {
          return ApiResponse(statusCode: 200, body: call('REJECTED'));
        }
        if (request.path.endsWith('hangup')) {
          return ApiResponse(statusCode: 200, body: call('ENDED'));
        }
        return const ApiResponse(statusCode: 503, body: null);
      };
      final repository = HttpCallRepository(
        api: transport,
        accessToken: () async => 'token',
      );
      final controller = CallController(repository: repository);
      expect((await controller.startCall('booking-1'))?.status.name, 'ringing');
      expect((await controller.answerCall()).status.name, 'connected');
      expect((await controller.hangupCall()).status.name, 'ended');
      await controller.startCall('booking-1');
      expect((await controller.rejectCall()).status.name, 'rejected');
      await expectLater(
        repository.getActiveCall('booking-1'),
        throwsA(isA<ApiException>()),
      );
      expect(transport.requests.every((r) => r.bearerToken == 'token'), isTrue);
      controller.dispose();
    },
  );

  test(
    'phone fallback validates numbers and does not create signaling records',
    () async {
      final transport = _Transport();
      Uri? opened;
      final controller = CallController(
        repository: HttpCallRepository(
          api: transport,
          accessToken: () async => 'token',
        ),
        phoneLauncher: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(await controller.launchCall('+91 (98765) 43210'), isTrue);
      expect(opened.toString(), 'tel:+919876543210');
      expect(await controller.launchCall('***43210'), isFalse);
      expect(await controller.launchCall('tel:123?x=y'), isFalse);
      expect(transport.requests, isEmpty);
      expect(controller.activeSession, isNull);
      controller.dispose();
    },
  );

  testWidgets(
    'call screen shows dialer handoff and launch failure without fake audio controls',
    (tester) async {
      final controller = CallController(phoneLauncher: (_) async => false);
      await tester.pumpWidget(
        MaterialApp(
          home: CallScreen(
            oppositePartyName: 'Service Specialist',
            oppositePartyRole: 'Service Specialist',
            phoneNumber: '+919876543210',
            controller: controller,
          ),
        ),
      );
      expect(
        find.textContaining('In-app audio calling is not available'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic_off), findsNothing);
      expect(find.text('00:00'), findsNothing);
      await tester.tap(find.text('Open phone app'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open the phone app'),
        findsOneWidget,
      );
      controller.dispose();
    },
  );

  test(
    'failed notification delete preserves item and does not poison later fetch',
    () async {
      final transport = _Transport();
      final pending = Completer<ApiResponse>();
      transport.handler = (request) async => request.method == ApiMethod.get
          ? ApiResponse(statusCode: 200, body: [notification('n-1')])
          : pending.future;
      final repository = NotificationRepository(
        api: transport,
        accessToken: () async => 'token',
      );
      final controller = NotificationController(repository);
      await controller.load();
      final deleting = controller.deleteNotification('n-1');
      expect(controller.notifications.single.id, 'n-1');
      pending.complete(
        const ApiResponse(statusCode: 503, body: {'success': false}),
      );
      expect(await deleting, isFalse);
      expect(controller.notifications.single.id, 'n-1');
      expect(controller.errorMessage, contains('not saved'));
      expect((await repository.fetchNotifications()).single.id, 'n-1');
      controller.dispose();
    },
  );

  test(
    'confirmed clear preserves notifications received during request',
    () async {
      final transport = _Transport();
      final pending = Completer<ApiResponse>();
      transport.handler = (request) async => request.method == ApiMethod.get
          ? ApiResponse(statusCode: 200, body: [notification('n-1')])
          : pending.future;
      final controller = NotificationController(
        NotificationRepository(
          api: transport,
          accessToken: () async => 'token',
        ),
      );
      await controller.load();
      final clearing = controller.clearAll();
      controller.addNotification(
        InAppNotification.fromJson(notification('new')),
      );
      pending.complete(
        const ApiResponse(statusCode: 200, body: {'success': true}),
      );
      expect(await clearing, isTrue);
      expect(controller.notifications.map((n) => n.id), ['new']);
      controller.dispose();
    },
  );

  test(
    'HTTP 200 unsuccessful acknowledgement does not erase notifications',
    () async {
      final transport = _Transport();
      transport.handler = (request) async => request.method == ApiMethod.get
          ? ApiResponse(statusCode: 200, body: [notification('n-1')])
          : const ApiResponse(statusCode: 200, body: {'success': false});
      final controller = NotificationController(
        NotificationRepository(
          api: transport,
          accessToken: () async => 'token',
        ),
      );
      await controller.load();
      expect(await controller.clearAll(), isFalse);
      expect(controller.notifications, hasLength(1));
      controller.dispose();
    },
  );
}
