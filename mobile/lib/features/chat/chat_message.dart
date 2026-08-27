class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderUserId,
    required this.senderRole,
    required this.messageText,
    required this.createdAt,
    this.clientMessageId,
    this.readAt,
    this.isMe = false,
  });

  final String id;
  final String bookingId;
  final String senderUserId;
  final String senderRole;
  final String messageText;
  final String? clientMessageId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMe;

  factory ChatMessage.fromJson(
    Map<String, Object?> json, {
    String? currentUserId,
    bool? overrideIsMe,
  }) {
    final senderId = json['senderUserId']?.toString() ?? '';
    final isMeCalculated = overrideIsMe ?? (currentUserId != null && currentUserId == senderId);

    DateTime parsedDate;
    final createdAtRaw = json['createdAt']?.toString();
    if (createdAtRaw != null) {
      parsedDate = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedReadAt;
    final readAtRaw = json['readAt']?.toString();
    if (readAtRaw != null) {
      parsedReadAt = DateTime.tryParse(readAtRaw);
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      senderUserId: senderId,
      senderRole: json['senderRole']?.toString() ?? 'CUSTOMER',
      messageText: json['messageText']?.toString() ?? '',
      clientMessageId: json['clientMessageId']?.toString(),
      createdAt: parsedDate,
      readAt: parsedReadAt,
      isMe: isMeCalculated,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? bookingId,
    String? senderUserId,
    String? senderRole,
    String? messageText,
    String? clientMessageId,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderRole: senderRole ?? this.senderRole,
      messageText: messageText ?? this.messageText,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe ?? this.isMe,
    );
  }
}
