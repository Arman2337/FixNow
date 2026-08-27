enum CallStatus {
  initiated,
  ringing,
  connected,
  ended,
  rejected,
  missed,
  failed;

  static CallStatus fromString(String raw) {
    switch (raw.toUpperCase()) {
      case 'INITIATED':
        return CallStatus.initiated;
      case 'RINGING':
        return CallStatus.ringing;
      case 'CONNECTED':
        return CallStatus.connected;
      case 'REJECTED':
        return CallStatus.rejected;
      case 'MISSED':
        return CallStatus.missed;
      case 'ENDED':
        return CallStatus.ended;
      default:
        return CallStatus.failed;
    }
  }

  String toApiString() => name.toUpperCase();
}

class CallSession {
  const CallSession({
    required this.id,
    required this.bookingId,
    required this.callerUserId,
    required this.callerRole,
    required this.calleeUserId,
    required this.status,
    required this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.durationSeconds,
  });

  final String id;
  final String bookingId;
  final String callerUserId;
  final String callerRole;
  final String calleeUserId;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  factory CallSession.fromJson(Map<String, Object?> json) {
    DateTime parsedStarted;
    final startedRaw = json['startedAt']?.toString();
    if (startedRaw != null) {
      parsedStarted = DateTime.tryParse(startedRaw) ?? DateTime.now();
    } else {
      parsedStarted = DateTime.now();
    }

    DateTime? parsedConnected;
    final connectedRaw = json['connectedAt']?.toString();
    if (connectedRaw != null) {
      parsedConnected = DateTime.tryParse(connectedRaw);
    }

    DateTime? parsedEnded;
    final endedRaw = json['endedAt']?.toString();
    if (endedRaw != null) {
      parsedEnded = DateTime.tryParse(endedRaw);
    }

    int? duration;
    final durRaw = json['durationSeconds'];
    if (durRaw is num) {
      duration = durRaw.toInt();
    }

    return CallSession(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      callerUserId: json['callerUserId']?.toString() ?? '',
      callerRole: json['callerRole']?.toString() ?? 'CUSTOMER',
      calleeUserId: json['calleeUserId']?.toString() ?? '',
      status: CallStatus.fromString(json['status']?.toString() ?? 'INITIATED'),
      startedAt: parsedStarted,
      connectedAt: parsedConnected,
      endedAt: parsedEnded,
      durationSeconds: duration,
    );
  }

  CallSession copyWith({
    String? id,
    String? bookingId,
    String? callerUserId,
    String? callerRole,
    String? calleeUserId,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallSession(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      callerUserId: callerUserId ?? this.callerUserId,
      callerRole: callerRole ?? this.callerRole,
      calleeUserId: calleeUserId ?? this.calleeUserId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
