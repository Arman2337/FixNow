enum ProviderApplicationStatus {
  unverified,
  underReview,
  approved,
  rejected,
  resubmissionRequested;

  static ProviderApplicationStatus parse(String value) => switch (value) {
    'under_review' => underReview,
    'approved' => approved,
    'rejected' => rejected,
    'resubmission_requested' => resubmissionRequested,
    _ => unverified,
  };
}

class ProviderApplication {
  const ProviderApplication({required this.status, this.reason});
  final ProviderApplicationStatus status;
  final String? reason;

  factory ProviderApplication.fromJson(Map<String, Object?> json) =>
      ProviderApplication(
        status: ProviderApplicationStatus.parse(
          json['status']?.toString() ?? '',
        ),
        reason: json['decisionReason'] as String?,
      );
}

class ProviderProfile {
  const ProviderProfile({
    required this.displayName,
    required this.bio,
    required this.serviceRadiusKm,
    required this.baseLatitude,
    required this.baseLongitude,
  });
  final String displayName;
  final String? bio;
  final double serviceRadiusKm;
  final double baseLatitude;
  final double baseLongitude;

  factory ProviderProfile.fromJson(Map<String, Object?> json) =>
      ProviderProfile(
        displayName: json['displayName'] as String,
        bio: json['bio'] as String?,
        serviceRadiusKm: (json['serviceRadiusKm'] as num).toDouble(),
        baseLatitude: (json['baseLatitude'] as num).toDouble(),
        baseLongitude: (json['baseLongitude'] as num).toDouble(),
      );
}

class ProviderAvailability {
  const ProviderAvailability({required this.status, required this.version});
  final String status;
  final int version;
  factory ProviderAvailability.fromJson(Map<String, Object?> json) =>
      ProviderAvailability(
        status: json['status'] as String,
        version: json['version'] as int,
      );
}
