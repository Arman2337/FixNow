class GuaranteeClaim {
  final String id;
  final String bookingId;
  final String customerId;
  final String? originalProviderId;
  final String status;
  final String description;
  final List<String>? evidenceUrls;
  final String? adminNotes;
  final String? assignedProviderId;
  final String? reServiceBookingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  GuaranteeClaim({
    required this.id,
    required this.bookingId,
    required this.customerId,
    this.originalProviderId,
    required this.status,
    required this.description,
    this.evidenceUrls,
    this.adminNotes,
    this.assignedProviderId,
    this.reServiceBookingId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuaranteeClaim.fromJson(Map<String, dynamic> json) {
    return GuaranteeClaim(
      id: json['id'],
      bookingId: json['bookingId'] ?? json['booking_id'],
      customerId: json['customerId'] ?? json['customer_id'],
      originalProviderId: json['originalProviderId'] ?? json['original_provider_id'],
      status: json['status'],
      description: json['description'],
      evidenceUrls: json['evidenceUrls'] != null ? List<String>.from(json['evidenceUrls']) : null,
      adminNotes: json['adminNotes'] ?? json['admin_notes'],
      assignedProviderId: json['assignedProviderId'] ?? json['assigned_provider_id'],
      reServiceBookingId: json['reServiceBookingId'] ?? json['re_service_booking_id'],
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['updated_at']),
    );
  }
}
