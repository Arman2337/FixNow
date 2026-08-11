class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool isExpired(DateTime now, {Duration skew = const Duration(seconds: 30)}) {
    return !expiresAt.isAfter(now.add(skew));
  }
}
