class CustomerProfileStats {
  const CustomerProfileStats({
    required this.completedJobs,
    required this.cashbackMinor,
    required this.activeWarranties,
  });
  final int completedJobs;
  final int cashbackMinor;
  final int activeWarranties;

  factory CustomerProfileStats.fromJson(Map<String, dynamic> json) {
    return CustomerProfileStats(
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      cashbackMinor: (json['cashbackMinor'] as num?)?.toInt() ?? 0,
      activeWarranties: (json['activeWarranties'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerProfile {
  const CustomerProfile({required this.displayName, this.stats});
  final String? displayName;
  final CustomerProfileStats? stats;

  factory CustomerProfile.fromJson(Object? rawJson) {
    final json = rawJson is Map<String, dynamic> ? rawJson : null;
    final value = json?['displayName'];
    if (value != null && value is! String) throw const FormatException();
    
    CustomerProfileStats? stats;
    if (json?['stats'] != null) {
      stats = CustomerProfileStats.fromJson(json!['stats'] as Map<String, dynamic>);
    }

    return CustomerProfile(displayName: value as String?, stats: stats);
  }
}
