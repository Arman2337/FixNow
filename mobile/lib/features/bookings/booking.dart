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

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.serviceCategoryId,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.version,
    this.locationLatitude,
    this.locationLongitude,
    this.scheduledAt,
    this.items,
    this.pricing,
    this.estimatedDurationMinutes,
  });
  final String id;
  final String serviceCategoryId;
  final String status;
  final String description;
  final DateTime createdAt;
  final int version;
  final double? locationLatitude;
  final double? locationLongitude;
  final DateTime? scheduledAt;
  final List<BookingLineItem>? items;
  final BookingPricing? pricing;
  final int? estimatedDurationMinutes;

  CustomerBooking copyWith({
    String? id,
    String? serviceCategoryId,
    String? status,
    String? description,
    DateTime? createdAt,
    int? version,
    double? locationLatitude,
    double? locationLongitude,
    DateTime? scheduledAt,
    List<BookingLineItem>? items,
    BookingPricing? pricing,
    int? estimatedDurationMinutes,
  }) =>
      CustomerBooking(
        id: id ?? this.id,
        serviceCategoryId: serviceCategoryId ?? this.serviceCategoryId,
        status: status ?? this.status,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        version: version ?? this.version,
        locationLatitude: locationLatitude ?? this.locationLatitude,
        locationLongitude: locationLongitude ?? this.locationLongitude,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        items: items ?? this.items,
        pricing: pricing ?? this.pricing,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      );

  factory CustomerBooking.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final category = json['serviceCategoryId'];
    final status = json['status'];
    final description = json['description'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final latitude = json['locationLat'];
    final longitude = json['locationLng'];
    final scheduledAt = json['scheduledAt'] != null
        ? DateTime.tryParse(json['scheduledAt'].toString())
        : null;
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
    );
  }
}
