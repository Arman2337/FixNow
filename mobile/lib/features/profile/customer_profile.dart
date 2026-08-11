class CustomerProfile {
  const CustomerProfile({required this.displayName});
  final String? displayName;

  factory CustomerProfile.fromJson(Object? rawJson) {
    final json = rawJson is Map<String, dynamic> ? rawJson : null;
    final value = json?['displayName'];
    if (value != null && value is! String) throw const FormatException();
    return CustomerProfile(displayName: value as String?);
  }
}
