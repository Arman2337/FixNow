import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    List<ChatMessage>? initialMessages,
    this.canSend = true,
  }) : messages = initialMessages ?? [];

  List<ChatMessage> messages;
  bool canSend;
  final List<String> sentMessages = [];

  @override
  Future<({List<ChatMessage> messages, bool canSend})> fetchMessages(
    String bookingId,
  ) async {
    return (messages: List<ChatMessage>.from(messages), canSend: canSend);
  }

  @override
  Future<ChatMessage> sendMessage(
    String bookingId,
    String messageText, {
    String? clientMessageId,
  }) async {
    sentMessages.add(messageText);
    final msg = ChatMessage(
      id: 'server-${sentMessages.length}',
      bookingId: bookingId,
      senderUserId: 'customer-1',
      senderRole: 'CUSTOMER',
      messageText: messageText,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now(),
      isMe: true,
    );
    messages.add(msg);
    return msg;
  }
}

void main() {
  group('BookingChatScreen', () {
    testWidgets('renders header, shield banner, and message history', (tester) async {
      final fakeRepo = FakeChatRepository(
        initialMessages: [
          ChatMessage(
            id: 'm1',
            bookingId: 'booking-12345678',
            senderUserId: 'provider-1',
            senderRole: 'PROVIDER',
            messageText: 'I am on my way, ETA 10 minutes.',
            createdAt: DateTime.parse('2026-08-27T10:00:00Z'),
            isMe: false,
          ),
          ChatMessage(
            id: 'm2',
            bookingId: 'booking-12345678',
            senderUserId: 'customer-1',
            senderRole: 'CUSTOMER',
            messageText: 'Sounds good, gate is unlocked.',
            createdAt: DateTime.parse('2026-08-27T10:02:00Z'),
            isMe: true,
          ),
        ],
      );

      final controller = ChatController(
        bookingId: 'booking-12345678',
        repository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingChatScreen(
            controller: controller,
            providerName: 'Arun Plumbing Specialist',
          ),
        ),
      );

      // Initial pump
      await tester.pump();
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Arun Plumbing Specialist'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('Booking #BOOKING-'), findsOneWidget);

      // Check privacy shield
      expect(
        find.text('Phone numbers are hidden to protect your privacy.'),
        findsOneWidget,
      );

      // Check message bubbles
      expect(find.text('I am on my way, ETA 10 minutes.'), findsOneWidget);
      expect(find.text('Sounds good, gate is unlocked.'), findsOneWidget);

      // Check quick canned responses are present
      expect(find.text('🚪 Buzz code is #'), findsOneWidget);
      expect(find.text('📍 At the front gate'), findsOneWidget);
      expect(find.text('🅿️ Park in driveway'), findsOneWidget);
    });

    testWidgets('tapping canned chip sends message immediately', (tester) async {
      final fakeRepo = FakeChatRepository();
      final controller = ChatController(
        bookingId: 'booking-123',
        repository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingChatScreen(
            controller: controller,
            providerName: 'Technician Test',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap '📍 At the front gate' chip
      await tester.tap(find.text('📍 At the front gate'));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentMessages, contains('📍 At the front gate'));
      expect(find.text('📍 At the front gate'), findsNWidgets(2));
    });

    testWidgets('submitting text from input bar sends message', (tester) async {
      final fakeRepo = FakeChatRepository();
      final controller = ChatController(
        bookingId: 'booking-123',
        repository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingChatScreen(
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(
        find.byType(TextField),
        'Please call when outside',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(fakeRepo.sentMessages, contains('Please call when outside'));
      expect(find.text('Please call when outside'), findsOneWidget);
    });

    testWidgets('shows read-only banner when canSend is false', (tester) async {
      final fakeRepo = FakeChatRepository(canSend: false);
      final controller = ChatController(
        bookingId: 'booking-completed-123',
        repository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingChatScreen(
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Service completed — chat history is now read-only.'),
        findsOneWidget,
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
      expect(textField.decoration?.hintText, 'Chat is read-only');
    });

    testWidgets('tapping call button triggers onCallPressed callback', (tester) async {
      final fakeRepo = FakeChatRepository();
      final controller = ChatController(
        bookingId: 'booking-123',
        repository: fakeRepo,
      );

      bool callTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BookingChatScreen(
            controller: controller,
            onCallPressed: () {
              callTriggered = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();

      expect(callTriggered, isTrue);
    });
  });
}
