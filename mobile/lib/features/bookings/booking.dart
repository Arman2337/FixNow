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

/// A line item sent when creating a booking (from the service cart).
class BookingItemDraft {
  const BookingItemDraft({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
    this.durationMinutes,
  });
  final String id;
  final String name;
  final int quantity;
  final int unitPriceMinor;
  final int? durationMinutes;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unitPriceMinor': unitPriceMinor,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      };
}

/// An itemized line stored on a booking by the backend.
class BookingLineItem {
  const BookingLineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
    this.durationMinutes,
  });
  final String id;
  final String name;
  final int quantity;
  final int unitPriceMinor;
  final int? durationMinutes;

  int get lineTotalMinor => unitPriceMinor * quantity;

  BookingItemDraft toDraft() => BookingItemDraft(
        id: id,
        name: name,
        quantity: quantity,
        unitPriceMinor: unitPriceMinor,
        durationMinutes: durationMinutes,
      );

  factory BookingLineItem.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final quantity = json['quantity'];
    final unitPriceMinor = json['unitPriceMinor'];
    if (id is! String ||
        name is! String ||
        quantity is! int ||
        unitPriceMinor is! int) {
      throw const FormatException();
    }
    return BookingLineItem(
      id: id,
      name: name,
      quantity: quantity,
      unitPriceMinor: unitPriceMinor,
      durationMinutes: json['durationMinutes'] is int
          ? json['durationMinutes'] as int
          : null,
    );
  }
}

/// Server-computed pricing for an itemized booking.
class BookingPricing {
  const BookingPricing({
    required this.subtotalMinor,
    required this.gstMinor,
    required this.totalMinor,
    required this.currency,
  });
  final int subtotalMinor;
  final int gstMinor;
  final int totalMinor;
  final String currency;

  String get formattedTotal {
    final rupees = totalMinor / 100;
    return '₹${rupees.toStringAsFixed(totalMinor % 100 == 0 ? 0 : 2)}';
  }

  factory BookingPricing.fromJson(Map<String, Object?> json) {
    final subtotal = json['subtotalMinor'];
    final gst = json['gstMinor'];
    final total = json['totalMinor'];
    final currency = json['currency'];
    if (subtotal is! int || gst is! int || total is! int || currency is! String) {
      throw const FormatException();
    }
    return BookingPricing(
      subtotalMinor: subtotal,
      gstMinor: gst,
      totalMinor: total,
      currency: currency,
    );
  }
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
    this.items,
    this.pricing,
    this.estimatedDurationMinutes,
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
  final List<BookingLineItem>? items;
  final BookingPricing? pricing;
  final int? estimatedDurationMinutes;
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
    List<BookingLineItem>? items,
    BookingPricing? pricing,
    int? estimatedDurationMinutes,
    List<LineItem>? lineItems,
  }) =>
      CustomerBooking(
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
        items: items ?? this.items,
        pricing: pricing ?? this.pricing,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? this.estimatedDurationMinutes,
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
    final rawItems = json['items'];
    final rawPricing = json['pricing'];
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
      items: rawItems is List && rawItems.isNotEmpty
          ? rawItems
              .map(
                (item) => BookingLineItem.fromJson(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .toList(growable: false)
          : null,
      pricing: rawPricing is Map
          ? BookingPricing.fromJson(Map<String, Object?>.from(rawPricing))
          : null,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] is int
          ? json['estimatedDurationMinutes'] as int
          : null,
      lineItems: lineItemsList
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
