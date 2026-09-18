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

class ProviderStats {
  const ProviderStats({
    required this.rating,
    required this.completedJobs,
    required this.earningsMinor,
    required this.acceptanceRate,
  });
  final double rating;
  final int completedJobs;
  final int earningsMinor;
  final int acceptanceRate;

  factory ProviderStats.fromJson(Map<String, Object?> json) {
    return ProviderStats(
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      earningsMinor: (json['earningsMinor'] as num?)?.toInt() ?? 0,
      acceptanceRate: (json['acceptanceRate'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProviderProfile {
  const ProviderProfile({
    required this.displayName,
    required this.bio,
    required this.serviceRadiusKm,
    required this.baseLatitude,
    required this.baseLongitude,
    this.stats,
  });
  final String displayName;
  final String? bio;
  final double serviceRadiusKm;
  final double baseLatitude;
  final double baseLongitude;
  final ProviderStats? stats;

  factory ProviderProfile.fromJson(Map<String, Object?> json) {
    ProviderStats? stats;
    if (json['stats'] != null) {
      stats = ProviderStats.fromJson(json['stats'] as Map<String, Object?>);
    }
    return ProviderProfile(
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      serviceRadiusKm: (json['serviceRadiusKm'] as num).toDouble(),
      baseLatitude: (json['baseLatitude'] as num).toDouble(),
      baseLongitude: (json['baseLongitude'] as num).toDouble(),
      stats: stats,
    );
  }
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

  String get scheduleSummary {
    if (weeklyRules.isEmpty) {
      return 'No recurring hours set.';
    }
    final days =
        weeklyRules
            .map((r) => (r['dayOfWeek'] as num?)?.toInt())
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();

    String timeStr = '09:00–17:00';
    if (weeklyRules.isNotEmpty) {
      final intervals = weeklyRules.first['intervals'] as List?;
      if (intervals != null && intervals.isNotEmpty) {
        final firstInterval = Map<String, Object?>.from(intervals.first as Map);
        final startMin = (firstInterval['startMinute'] as num?)?.toInt() ?? 540;
        final endMin = (firstInterval['endMinute'] as num?)?.toInt() ?? 1020;
        final startH = (startMin ~/ 60).toString().padLeft(2, '0');
        final startM = (startMin % 60).toString().padLeft(2, '0');
        final endH = (endMin ~/ 60).toString().padLeft(2, '0');
        final endM = (endMin % 60).toString().padLeft(2, '0');
        timeStr = '$startH:$startM–$endH:$endM';
      }
    }

    final isMonToFri =
        days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5);
    final isMonToSat =
        days.length == 6 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5) &&
        days.contains(6);
    final isAllWeek = days.length == 7;

    String daysStr;
    if (isAllWeek) {
      daysStr = 'Every day';
    } else if (isMonToSat) {
      daysStr = 'Monday to Saturday';
    } else if (isMonToFri) {
      daysStr = 'Monday to Friday';
    } else {
      const dayNames = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        0: 'Sun',
      };
      daysStr = days
          .map((d) => dayNames[d] ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    }

    return '$daysStr, $timeStr $timeZone';
  }

  String get timingSummary {
    if (weeklyRules.isEmpty) {
      return 'No recurring hours set.';
    }
    String timeStr = '09:00–17:00';
    final intervals = weeklyRules.first['intervals'] as List?;
    if (intervals != null && intervals.isNotEmpty) {
      final firstInterval = Map<String, Object?>.from(intervals.first as Map);
      final startMin = (firstInterval['startMinute'] as num?)?.toInt() ?? 540;
      final endMin = (firstInterval['endMinute'] as num?)?.toInt() ?? 1020;
      final startH = (startMin ~/ 60).toString().padLeft(2, '0');
      final startM = (startMin % 60).toString().padLeft(2, '0');
      final endH = (endMin ~/ 60).toString().padLeft(2, '0');
      final endM = (endMin % 60).toString().padLeft(2, '0');
      timeStr = '$startH:$startM–$endH:$endM';
    }
    return timeStr;
  }
}

class ProviderSkill {
  const ProviderSkill({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.verified,
  });
  final String id;
  final String categoryId;
  final String categoryName;
  final bool verified;
  factory ProviderSkill.fromJson(Map<String, Object?> json) {
    final category = Map<String, Object?>.from(json['serviceCategory'] as Map);
    return ProviderSkill(
      id: json['id'] as String,
      categoryId: category['id'] as String? ?? '',
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

class ProviderRequest {
  const ProviderRequest({
    required this.id,
    required this.serviceCategoryId,
    required this.description,
    required this.createdAt,
    required this.version,
    required this.distanceKm,
    this.customerPhone,
  });

  final String id;
  final String serviceCategoryId;
  final String description;
  final DateTime createdAt;
  final int version;
  final double distanceKm;
  final String? customerPhone;

  factory ProviderRequest.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final category = json['serviceCategoryId'];
    final description = json['description'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final distance = json['distanceKm'];
    final customerPhone = json['customerPhone'] as String?;
    if (id is! String || category is! String || createdAt == null) {
      throw const FormatException();
    }
    return ProviderRequest(
      id: id,
      serviceCategoryId: category,
      description: description?.toString() ?? 'Service Request',
      createdAt: createdAt,
      version: (json['version'] as num?)?.toInt() ?? 1,
      distanceKm: (distance as num?)?.toDouble() ?? 0.0,
      customerPhone: customerPhone,
    );
  }
}

/// FN-111: rolling accept-time signal. [averageAcceptMinutes] is null until
/// enough accepted jobs exist; callers must hide the card entirely then.
class ProviderAcceptTime {
  const ProviderAcceptTime({
    required this.averageAcceptMinutes,
    required this.sampleSize,
    required this.windowDays,
  });
  final int? averageAcceptMinutes;
  final int sampleSize;
  final int windowDays;

  factory ProviderAcceptTime.fromJson(Map<String, Object?> json) {
    final average = json['averageAcceptMinutes'];
    final sampleSize = json['sampleSize'];
    final windowDays = json['windowDays'];
    if (sampleSize is! int || windowDays is! int) {
      throw const FormatException();
    }
    return ProviderAcceptTime(
      averageAcceptMinutes: average is int ? average : null,
      sampleSize: sampleSize,
      windowDays: windowDays,
    );
  }
}
