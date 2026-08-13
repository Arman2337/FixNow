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
  const ProviderAvailability({
    required this.status,
    required this.version,
    required this.timeZone,
    required this.weeklyRules,
  });
  final String status;
  final int version;
  final String timeZone;
  final List<Map<String, Object?>> weeklyRules;
  factory ProviderAvailability.fromJson(Map<String, Object?> json) =>
      ProviderAvailability(
        status: json['status'] as String,
        version: json['version'] as int,
        timeZone: json['timeZone'] as String? ?? 'UTC',
        weeklyRules: (json['weeklyRules'] as List? ?? const [])
            .map((rule) => Map<String, Object?>.from(rule as Map))
            .toList(),
      );
}

class ProviderSkill {
  const ProviderSkill({
    required this.id,
    required this.categoryName,
    required this.verified,
  });
  final String id;
  final String categoryName;
  final bool verified;
  factory ProviderSkill.fromJson(Map<String, Object?> json) {
    final category = Map<String, Object?>.from(json['serviceCategory'] as Map);
    return ProviderSkill(
      id: json['id'] as String,
      categoryName: category['name'] as String,
      verified: json['isVerified'] as bool,
    );
  }
}

class ProviderDocument {
  const ProviderDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.sizeBytes,
  });
  final String id;
  final String type;
  final String status;
  final int sizeBytes;
  factory ProviderDocument.fromJson(Map<String, Object?> json) =>
      ProviderDocument(
        id: json['id'] as String,
        type: json['documentType'] as String,
        status: json['status'] as String,
        sizeBytes: json['sizeBytes'] as int,
      );
}
