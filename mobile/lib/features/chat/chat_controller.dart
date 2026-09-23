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
    String? currentUserId,
    this.isProvider = false,
  }) : currentUserId = currentUserId ?? repository.currentUserId {
    _init();
  }

  final String bookingId;
  final ChatRepository repository;
  final RealtimeClient? realtimeClient;
  final String? currentUserId;
  final bool isProvider;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canSend = true;
  String? _errorMessage;
  StreamSubscription<RealtimeProjection>? _realtimeSub;
  Timer? _pollTimer;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get canSend => _canSend;
  String? get errorMessage => _errorMessage;

  void _init() {
    load();
    _listenToRealtime();
    realtimeClient?.subscribeBooking(bookingId);
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isSending) {
        _pollMessages();
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollMessages() async {
    try {
      final result = await repository.fetchMessages(bookingId);
      _canSend = result.canSend;
      bool changed = false;
      for (final msg in result.messages) {
        final idx = _messages.indexWhere(
          (m) =>
              m.id == msg.id ||
              (msg.clientMessageId != null &&
                  m.clientMessageId == msg.clientMessageId),
        );
        if (idx < 0) {
          _messages.add(msg);
          changed = true;
        } else if (_messages[idx].readAt != msg.readAt) {
          _messages[idx] = msg;
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {}
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
    final effectiveIsMe =
        (currentUserId != null && message.senderUserId == currentUserId) ||
        message.isMe;
    final resolved = message.copyWith(isMe: effectiveIsMe);

    // Check if already in list by ID or clientMessageId
    final index = _messages.indexWhere(
      (m) =>
          m.id == resolved.id ||
          (resolved.clientMessageId != null &&
              m.clientMessageId == resolved.clientMessageId),
    );

    if (index >= 0) {
      _messages[index] = resolved;
    } else {
      _messages.add(resolved);
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
      senderUserId: currentUserId ?? (isProvider ? 'provider' : 'customer'),
      senderRole: isProvider ? 'PROVIDER' : 'CUSTOMER',
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

      final idx = _messages.indexWhere(
        (m) => m.clientMessageId == tempClientId,
      );
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
    _pollTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }
}
