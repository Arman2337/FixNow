enum BookingStatusValue {
  requested,
  assigned,
  enRoute,
  inProgress,
  completed,
  cancelled,
  unknown;

  static BookingStatusValue parse(String raw) =>
      switch (raw.trim().toUpperCase()) {
        'REQUESTED' => BookingStatusValue.requested,
        'ASSIGNED' => BookingStatusValue.assigned,
        'EN_ROUTE' => BookingStatusValue.enRoute,
        'IN_PROGRESS' => BookingStatusValue.inProgress,
        'COMPLETED' => BookingStatusValue.completed,
        'CANCELLED' => BookingStatusValue.cancelled,
        _ => BookingStatusValue.unknown,
      };

  bool get isActive => const {
    BookingStatusValue.requested,
    BookingStatusValue.assigned,
    BookingStatusValue.enRoute,
    BookingStatusValue.inProgress,
  }.contains(this);

  bool get isCompleted => this == BookingStatusValue.completed;
  bool get isCancelled => this == BookingStatusValue.cancelled;

  String get label => switch (this) {
    BookingStatusValue.requested => 'Matching specialists',
    BookingStatusValue.assigned => 'Provider assigned',
    BookingStatusValue.enRoute => 'En route',
    BookingStatusValue.inProgress => 'Work in progress',
    BookingStatusValue.completed => 'Completed',
    BookingStatusValue.cancelled => 'Cancelled',
    BookingStatusValue.unknown => 'Status unavailable',
  };
}

class LineItem {
  const LineItem({
    required this.type,
    required this.description,
    required this.amount,
  });
  
  final String type;
  final String description;
  final num amount;

  factory LineItem.fromJson(Map<String, Object?> json) {
    return LineItem(
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'amount': amount,
  };
}

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.serviceCategoryId,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.version,
    this.customerPhone,
    this.providerPhone,
    this.locationLatitude,
    this.locationLongitude,
    this.scheduledAt,
    this.lineItems = const [],
  });
  final String id;
  final String serviceCategoryId;
  final String status;
  final String description;
  final DateTime createdAt;
  final int version;
  final String? customerPhone;
  final String? providerPhone;
  final double? locationLatitude;
  final double? locationLongitude;
  final DateTime? scheduledAt;
  final List<LineItem> lineItems;

  BookingStatusValue get statusValue => BookingStatusValue.parse(status);

  CustomerBooking copyWith({
    String? id,
    String? serviceCategoryId,
    String? status,
    String? description,
    DateTime? createdAt,
    int? version,
    String? customerPhone,
    String? providerPhone,
    double? locationLatitude,
    double? locationLongitude,
    DateTime? scheduledAt,
    List<LineItem>? lineItems,
  }) => CustomerBooking(
    id: id ?? this.id,
    serviceCategoryId: serviceCategoryId ?? this.serviceCategoryId,
    status: status ?? this.status,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    version: version ?? this.version,
    customerPhone: customerPhone ?? this.customerPhone,
    providerPhone: providerPhone ?? this.providerPhone,
    locationLatitude: locationLatitude ?? this.locationLatitude,
    locationLongitude: locationLongitude ?? this.locationLongitude,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    lineItems: lineItems ?? this.lineItems,
  );

  factory CustomerBooking.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final category = json['serviceCategoryId'];
    final status = json['status'];
    final description = json['description'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final customerPhone = json['customerPhone'] as String?;
    final providerPhone = json['providerPhone'] as String?;
    final latitude = json['locationLat'];
    final longitude = json['locationLng'];
    final scheduledAt = json['scheduledAt'] != null
        ? DateTime.tryParse(json['scheduledAt'].toString())
        : null;
    final lineItemsList = json['lineItems'] as List<dynamic>? ?? [];
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
      customerPhone: customerPhone,
      providerPhone: providerPhone,
      locationLatitude: latitude is num ? latitude.toDouble() : null,
      locationLongitude: longitude is num ? longitude.toDouble() : null,
      scheduledAt: scheduledAt,
      lineItems: lineItemsList
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
