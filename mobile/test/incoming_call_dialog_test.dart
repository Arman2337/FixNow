import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/call/incoming_call_dialog.dart';

class _FakeCallRepository implements CallRepository {
  @override
  Future<CallSession?> getActiveCall(String bookingId) async => null;

  @override
  Future<CallSession> hangupCall(String bookingId, String callId) async =>
      CallSession(
        id: callId,
        bookingId: bookingId,
        callerUserId: 'provider-1',
        callerRole: 'PROVIDER',
        calleeUserId: 'customer-1',
        status: CallStatus.ended,
        startedAt: DateTime.now(),
      );

  @override
  Future<CallSession> answerCall(String bookingId, String callId) async =>
      CallSession(
        id: callId,
        bookingId: bookingId,
        callerUserId: 'provider-1',
        callerRole: 'PROVIDER',
        calleeUserId: 'customer-1',
        status: CallStatus.connected,
        startedAt: DateTime.now(),
        connectedAt: DateTime.now(),
      );

  @override
  Future<CallSession> initiateCall(String bookingId) async => CallSession(
    id: 'call-1',
    bookingId: bookingId,
    callerUserId: 'provider-1',
    callerRole: 'PROVIDER',
    calleeUserId: 'customer-1',
    status: CallStatus.ringing,
    startedAt: DateTime.now(),
  );

  @override
  Future<CallSession> rejectCall(String bookingId, String callId) async =>
      CallSession(
        id: callId,
        bookingId: bookingId,
        callerUserId: 'provider-1',
        callerRole: 'PROVIDER',
        calleeUserId: 'customer-1',
        status: CallStatus.rejected,
        startedAt: DateTime.now(),
      );
}

CallSession _session() => CallSession(
  id: 'call-ringing',
  bookingId: 'booking-123',
  callerUserId: 'provider-1',
  callerRole: 'PROVIDER',
  calleeUserId: 'customer-1',
  status: CallStatus.ringing,
  startedAt: DateTime.now(),
);

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('renders caller title, action buttons, and wave rings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        IncomingCallDialog(
          session: _session(),
          repository: _FakeCallRepository(),
          callerTitle: 'Verified Service Technician',
        ),
      ),
    );
    // Repeating controllers — pump forward in steps, NEVER pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Verified Service Technician'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
  });

  testWidgets('rings animate while pulsing (transform layers present)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        IncomingCallDialog(
          session: _session(),
          repository: _FakeCallRepository(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Avatar scale + two wave rings all resolve to Transform widgets.
    expect(find.byType(Transform), findsWidgets);
  });

  testWidgets('reduce motion stops the ambient loops but keeps the UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        IncomingCallDialog(
          session: _session(),
          repository: _FakeCallRepository(),
          callerTitle: 'Verified Service Technician',
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Accept'), findsOneWidget);
    expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
    // The avatar's ScaleTransition stays in the tree but is pinned: its
    // controller is stopped at mid-pulse by the reduce-motion guard.
    final scale = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).first,
    );
    expect(scale.scale.value, 1.0);
  });
}
