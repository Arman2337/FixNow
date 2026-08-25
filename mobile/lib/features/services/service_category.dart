class ServiceCategoryPricing {
  const ServiceCategoryPricing({
    required this.amountMinor,
    required this.currency,
  });
  final int amountMinor;
  final String currency;

  factory ServiceCategoryPricing.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException();
    final amountMinor = json['amountMinor'];
    final currency = json['currency'];
    if (amountMinor is! int || currency is! String) {
      throw const FormatException();
    }
    return ServiceCategoryPricing(amountMinor: amountMinor, currency: currency);
  }

  /// Human display, e.g. ₹499. Minor units assumed paise for INR; other
  /// currencies fall back to a plain minor-unit amount until widened.
  String get displayLabel {
    if (currency == 'INR') {
      return '₹${(amountMinor / 100).toStringAsFixed(amountMinor % 100 == 0 ? 0 : 2)}';
    }
    return '$amountMinor $currency';
  }
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconName,
    this.pricing,
    this.isEmergency = false,
    this.verifiedProCount = 0,
    this.onlineProCount = 0,
    this.rating,
    this.reviewCount = 0,
  });
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconName;
  final ServiceCategoryPricing? pricing;

  /// Whether this category is flagged for emergency/priority dispatch on the
  /// backend (e.g. Locksmith, Emergency Repair). Real data, not a heuristic.
  final bool isEmergency;

  /// Number of verified providers offering this category who hold an active
  /// account. Real backend data; 0 until providers register — never a
  /// placeholder.
  final int verifiedProCount;

  /// Of the verified providers, how many are online right now (real-time
  /// presence). 0 when none are live.
  final int onlineProCount;

  /// Average published-review rating (1–5), or null when the category has no
  /// reviews yet.
  final double? rating;

  /// Number of published reviews behind [rating]. 0 when none.
  final int reviewCount;

  factory ServiceCategory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final slug = json['slug'];
    if (id is! String || name is! String || slug is! String) {
      throw const FormatException();
    }
    return ServiceCategory(
      id: id,
      name: name,
      slug: slug,
      description: json['description'] is String
          ? json['description']! as String
          : null,
      iconName: json['iconName'] is String ? json['iconName']! as String : null,
      pricing: json['pricing'] == null
          ? null
          : ServiceCategoryPricing.fromJson(json['pricing']),
      isEmergency: json['isEmergency'] == true,
      verifiedProCount: (json['verifiedProCount'] as num?)?.toInt() ?? 0,
      onlineProCount: (json['onlineProCount'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}
