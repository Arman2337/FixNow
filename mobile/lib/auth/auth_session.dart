class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.verificationEmail,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? verificationEmail;

  bool isExpired(DateTime now, {Duration skew = const Duration(seconds: 30)}) {
    return !expiresAt.isAfter(now.add(skew));
  }
}
