class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.serviceCategoryId,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.version,
  });
  final String id;
  final String serviceCategoryId;
  final String status;
  final String description;
  final DateTime createdAt;
  final int version;

  factory CustomerBooking.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final category = json['serviceCategoryId'];
    final status = json['status'];
    final description = json['description'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id is! String ||
        category is! String ||
        status is! String ||
        description is! String ||
        createdAt == null) {
      throw const FormatException();
    }
    return CustomerBooking(
      id: id,
      serviceCategoryId: category,
      status: status,
      description: description,
      createdAt: createdAt,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}
