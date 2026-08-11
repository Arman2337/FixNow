class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconName,
  });
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconName;

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
    );
  }
}
