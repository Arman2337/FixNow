import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';

class FakeCallRepository implements CallRepository {
  CallSession? lastInitiated;
  bool answered = false;
  bool hungUp = false;

  @override
  Future<CallSession> initiateCall(String bookingId) async {
    final session = CallSession(
      id: 'call-123',
      bookingId: bookingId,
      callerUserId: 'customer-1',
      callerRole: 'CUSTOMER',
      calleeUserId: 'provider-1',
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
    );
    lastInitiated = session;
    return session;
  }

  @override
  Future<CallSession> answerCall(String bookingId, String callId) async {
    answered = true;
    return CallSession(
      id: callId,
      bookingId: bookingId,
      callerUserId: 'customer-1',
      callerRole: 'CUSTOMER',
      calleeUserId: 'provider-1',
      status: CallStatus.connected,
      startedAt: DateTime.now(),
      connectedAt: DateTime.now(),
    );
  }

  @override
  Future<CallSession> rejectCall(String bookingId, String callId) async {
    return CallSession(
      id: callId,
      bookingId: bookingId,
      callerUserId: 'customer-1',
      callerRole: 'CUSTOMER',
      calleeUserId: 'provider-1',
      status: CallStatus.rejected,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<CallSession> hangupCall(String bookingId, String callId) async {
    hungUp = true;
    return CallSession(
      id: callId,
      bookingId: bookingId,
      callerUserId: 'customer-1',
      callerRole: 'CUSTOMER',
      calleeUserId: 'provider-1',
      status: CallStatus.ended,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: 12,
    );
  }
}

void main() {
  group('BookingCallScreen Tests', () {
    late FakeCallRepository repo;

    setUp(() {
      repo = FakeCallRepository();
    });

    testWidgets('renders caller details, privacy shield, and initial status', (
      tester,
    ) async {
      final controller = CallController(
        bookingId: 'booking-abc',
        repository: repo,
        autoStart: false,
        initialSession: CallSession(
          id: 'call-001',
          bookingId: 'booking-abc',
          callerUserId: 'customer-1',
          callerRole: 'CUSTOMER',
          calleeUserId: 'provider-1',
          status: CallStatus.ringing,
          startedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingCallScreen(
            controller: controller,
            providerName: 'Alex Mercer',
            serviceTitle: 'Plumbing Repair',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alex Mercer'), findsOneWidget);
      expect(find.text('Plumbing Repair'), findsOneWidget);
      expect(find.text('Ringing...'), findsOneWidget);
      expect(
        find.text('Masked In-App Audio • Numbers Protected'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('toggles Mute microphone state', (tester) async {
      final controller = CallController(
        bookingId: 'booking-abc',
        repository: repo,
        autoStart: false,
        initialSession: CallSession(
          id: 'call-001',
          bookingId: 'booking-abc',
          callerUserId: 'customer-1',
          callerRole: 'CUSTOMER',
          calleeUserId: 'provider-1',
          status: CallStatus.connected,
          startedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingCallScreen(
            controller: controller,
            providerName: 'Alex Mercer',
          ),
        ),
      );
      await tester.pump();

      expect(controller.isMuted, isFalse);
      expect(find.text('Mute'), findsOneWidget);

      await tester.tap(find.text('Mute'));
      await tester.pump();

      expect(controller.isMuted, isTrue);
      expect(find.text('Unmute'), findsOneWidget);

      await tester.tap(find.text('Unmute'));
      await tester.pump();

      expect(controller.isMuted, isFalse);
      expect(find.text('Mute'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('toggles Speakerphone state', (tester) async {
      final controller = CallController(
        bookingId: 'booking-abc',
        repository: repo,
        autoStart: false,
        initialSession: CallSession(
          id: 'call-001',
          bookingId: 'booking-abc',
          callerUserId: 'customer-1',
          callerRole: 'CUSTOMER',
          calleeUserId: 'provider-1',
          status: CallStatus.connected,
          startedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingCallScreen(
            controller: controller,
            providerName: 'Alex Mercer',
          ),
        ),
      );
      await tester.pump();

      expect(controller.isSpeakerOn, isFalse);

      await tester.tap(find.text('Speaker'));
      await tester.pump();

      expect(controller.isSpeakerOn, isTrue);

      controller.dispose();
    });

    testWidgets('tapping End Call triggers hangup', (tester) async {
      final controller = CallController(
        bookingId: 'booking-abc',
        repository: repo,
        autoStart: false,
        initialSession: CallSession(
          id: 'call-001',
          bookingId: 'booking-abc',
          callerUserId: 'customer-1',
          callerRole: 'CUSTOMER',
          calleeUserId: 'provider-1',
          status: CallStatus.connected,
          startedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingCallScreen(
            controller: controller,
            providerName: 'Alex Mercer',
          ),
        ),
      );
      await tester.pump();

      expect(controller.status, CallStatus.connected);

      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();

      expect(controller.status, CallStatus.ended);
      expect(repo.hungUp, isTrue);

      controller.dispose();
    });
  });
}
