import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.bookingId,
    required this.repository,
    this.realtimeClient,
    this.currentUserId,
  }) {
    _init();
  }

  final String bookingId;
  final ChatRepository repository;
  final RealtimeClient? realtimeClient;
  final String? currentUserId;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canSend = true;
  String? _errorMessage;
  StreamSubscription<RealtimeProjection>? _realtimeSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get canSend => _canSend;
  String? get errorMessage => _errorMessage;

  void _init() {
    load();
    _listenToRealtime();
  }

  void _listenToRealtime() {
    if (realtimeClient == null) return;
    _realtimeSub = realtimeClient!.projections.listen((projection) {
      final type = projection.data['type']?.toString();
      if (type == 'chat.message-received.v1' || type == 'chat.message.v1') {
        final payload = projection.data['data'];
        if (payload is Map) {
          final msg = ChatMessage.fromJson(
            Map<String, Object?>.from(payload),
            currentUserId: currentUserId,
          );
          if (msg.bookingId == bookingId) {
            _appendRealtimeMessage(msg);
          }
        }
      }
    });
  }

  void _appendRealtimeMessage(ChatMessage message) {
    // Check if already in list by ID or clientMessageId
    final index = _messages.indexWhere(
      (m) =>
          m.id == message.id ||
          (message.clientMessageId != null &&
              m.clientMessageId == message.clientMessageId),
    );

    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
    }
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.fetchMessages(bookingId);
      _messages = List.of(result.messages);
      _canSend = result.canSend;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not load messages. Tap to retry.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_canSend || _isSending) return false;

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    final tempClientId = 'client-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempClientId,
      bookingId: bookingId,
      senderUserId: currentUserId ?? 'me',
      senderRole: 'CUSTOMER',
      messageText: trimmed,
      clientMessageId: tempClientId,
      createdAt: DateTime.now(),
      isMe: true,
    );

    // Optimistically add to messages list
    _messages.add(optimisticMessage);
    notifyListeners();

    try {
      final sent = await repository.sendMessage(
        bookingId,
        trimmed,
        clientMessageId: tempClientId,
      );

      final idx = _messages.indexWhere((m) => m.clientMessageId == tempClientId);
      if (idx >= 0) {
        _messages[idx] = sent.copyWith(isMe: true);
      } else {
        _messages.add(sent.copyWith(isMe: true));
      }
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Remove optimistic message or mark error
      _messages.removeWhere((m) => m.clientMessageId == tempClientId);
      _errorMessage = 'Failed to send message. Please retry.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
