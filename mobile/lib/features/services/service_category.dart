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
  });
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconName;
  final ServiceCategoryPricing? pricing;

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
    );
  }
}
