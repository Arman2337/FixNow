class RestorableAppRoute {
  const RestorableAppRoute({
    required this.userId,
    required this.name,
    this.argument,
  });

  final String userId;
  final String name;
  final String? argument;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestorableAppRoute &&
          other.userId == userId &&
          other.name == name &&
          other.argument == argument;

  @override
  int get hashCode => Object.hash(userId, name, argument);
}

class AppRouteRestorationStore {
  const AppRouteRestorationStore({
    required this.read,
    required this.write,
    required this.delete,
  });

  static const storageKey = 'fixnow.active_route';

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) delete;

  Future<RestorableAppRoute?> readRoute() async {
    final raw = await read(storageKey);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0].isEmpty) return null;
    if (parts[1] != 'tracking' && parts[1] != 'notifications') return null;
    return RestorableAppRoute(
      userId: parts[0],
      name: parts[1],
      argument: parts[2].isEmpty ? null : parts[2],
    );
  }

  Future<void> saveTracking({
    required String userId,
    required String bookingId,
  }) {
    return write(storageKey, '$userId|tracking|$bookingId');
  }

  Future<void> saveNotifications({required String userId}) {
    return write(storageKey, '$userId|notifications|');
  }

  Future<void> clear() => delete(storageKey);
}
