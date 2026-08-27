import 'package:flutter/material.dart';

/// Represents a granular sub-service task under a main service category
/// (e.g., "Tap & Mixer Repair" under "Plumbing").
class SubServiceItem {
  const SubServiceItem({
    required this.id,
    required this.categorySlug,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.durationMinutes,
    this.icon = Icons.build_rounded,
    this.badge,
  });

  final String id;
  final String categorySlug;
  final String name;
  final String description;
  final int priceMinor; // in paise
  final int durationMinutes;
  final IconData icon;
  final String? badge;

  String get formattedPrice {
    final rupees = priceMinor / 100;
    return '₹${rupees.toStringAsFixed(priceMinor % 100 == 0 ? 0 : 2)}';
  }

  String get formattedDuration => '$durationMinutes mins';
}

/// A line item in the customer's active service cart.
class CartItem {
  const CartItem({
    required this.subService,
    required this.quantity,
  });

  final SubServiceItem subService;
  final int quantity;

  int get itemTotalMinor => subService.priceMinor * quantity;

  String get formattedTotal {
    final rupees = itemTotalMinor / 100;
    return '₹${rupees.toStringAsFixed(itemTotalMinor % 100 == 0 ? 0 : 2)}';
  }

  CartItem copyWith({int? quantity}) => CartItem(
        subService: subService,
        quantity: quantity ?? this.quantity,
      );
}

/// In-memory state manager for the multi-item sub-service cart.
class ServiceCartController extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  int get totalPriceMinor =>
      _items.values.fold(0, (sum, item) => sum + item.itemTotalMinor);

  int get gstMinor => (totalPriceMinor * 0.18).round();

  int get grandTotalMinor => totalPriceMinor + gstMinor;

  String get formattedSubtotal {
    final rupees = totalPriceMinor / 100;
    return '₹${rupees.toStringAsFixed(totalPriceMinor % 100 == 0 ? 0 : 2)}';
  }

  String get formattedGst {
    final rupees = gstMinor / 100;
    return '₹${rupees.toStringAsFixed(gstMinor % 100 == 0 ? 0 : 2)}';
  }

  String get formattedGrandTotal {
    final rupees = grandTotalMinor / 100;
    return '₹${rupees.toStringAsFixed(grandTotalMinor % 100 == 0 ? 0 : 2)}';
  }

  int getQuantity(String subServiceId) =>
      _items[subServiceId]?.quantity ?? 0;

  void add(SubServiceItem subService) {
    if (_items.containsKey(subService.id)) {
      _items[subService.id] = _items[subService.id]!.copyWith(
        quantity: _items[subService.id]!.quantity + 1,
      );
    } else {
      _items[subService.id] = CartItem(subService: subService, quantity: 1);
    }
    notifyListeners();
  }

  void decrement(SubServiceItem subService) {
    if (!_items.containsKey(subService.id)) return;
    final currentQty = _items[subService.id]!.quantity;
    if (currentQty > 1) {
      _items[subService.id] = _items[subService.id]!.copyWith(
        quantity: currentQty - 1,
      );
    } else {
      _items.remove(subService.id);
    }
    notifyListeners();
  }

  void remove(String subServiceId) {
    if (_items.remove(subServiceId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Formatted description string summarizing all items in the cart
  /// (e.g. "Tap & Mixer Repair (x2), Shower & Pipe Leakage (x1)").
  String get summaryDescription {
    return _items.values
        .map((item) => '${item.subService.name} (x${item.quantity})')
        .join(', ');
  }
}

/// Catalog data source with pre-curated sub-services for each platform category.
class SubServiceCatalog {
  static List<SubServiceItem> getSubServicesForCategory(String categorySlug) {
    return _catalog[categorySlug] ?? _defaultFallback(categorySlug);
  }

  static List<SubServiceItem> getAllSubServices() {
    final all = <SubServiceItem>[];
    for (final items in _catalog.values) {
      all.addAll(items);
    }
    return all;
  }

  static const Map<String, List<SubServiceItem>> _catalog = {
    'plumbing': [
      SubServiceItem(
        id: 'plumb-1',
        categorySlug: 'plumbing',
        name: 'Tap & Mixer Repair',
        description: 'Fix leaking taps, replacement of spindles, washers & cartridges',
        priceMinor: 14900, // ₹149
        durationMinutes: 30,
        icon: Icons.water_drop_rounded,
        badge: 'MOST POPULAR',
      ),
      SubServiceItem(
        id: 'plumb-2',
        categorySlug: 'plumbing',
        name: 'Flush Tank & Jet Spray Fix',
        description: 'Repair cistern siphon, ball valve or install health faucet',
        priceMinor: 24900, // ₹249
        durationMinutes: 45,
        icon: Icons.sanitizer_rounded,
      ),
      SubServiceItem(
        id: 'plumb-3',
        categorySlug: 'plumbing',
        name: 'Shower & Water Pipe Leakage',
        description: 'Under-sink pipe joints, concealed pipe leakage inspection',
        priceMinor: 34900, // ₹349
        durationMinutes: 60,
        icon: Icons.shower_rounded,
      ),
      SubServiceItem(
        id: 'plumb-4',
        categorySlug: 'plumbing',
        name: 'Drain & Basin Clog Removal',
        description: 'Deep unblocking of kitchen sinks, bathroom floor traps & gullies',
        priceMinor: 39900, // ₹399
        durationMinutes: 45,
        icon: Icons.cleaning_services_rounded,
      ),
      SubServiceItem(
        id: 'plumb-5',
        categorySlug: 'plumbing',
        name: 'Overhead Tank Overflow & Float',
        description: 'Float valve replacement, overflow sensor troubleshooting',
        priceMinor: 49900, // ₹499
        durationMinutes: 60,
        icon: Icons.waves_rounded,
      ),
    ],
    'electrical': [
      SubServiceItem(
        id: 'elec-1',
        categorySlug: 'electrical',
        name: 'Switchboard / Socket Repair',
        description: 'Repair loose connections, replace damaged 6A/16A switches',
        priceMinor: 14900, // ₹149
        durationMinutes: 25,
        icon: Icons.power_rounded,
        badge: 'POPULAR',
      ),
      SubServiceItem(
        id: 'elec-2',
        categorySlug: 'electrical',
        name: 'Ceiling Fan / Light Fixture Fix',
        description: 'Installation, regulator check, capacitor replacement & balancing',
        priceMinor: 19900, // ₹199
        durationMinutes: 35,
        icon: Icons.lightbulb_rounded,
      ),
      SubServiceItem(
        id: 'elec-3',
        categorySlug: 'electrical',
        name: 'MCB & Fuse Trip Troubleshooting',
        description: 'Diagnose short circuits, replace tripped breaker or isolator',
        priceMinor: 29900, // ₹299
        durationMinutes: 45,
        icon: Icons.flash_on_rounded,
      ),
      SubServiceItem(
        id: 'elec-4',
        categorySlug: 'electrical',
        name: 'Heavy Appliance Power Wiring',
        description: 'Dedicated 25A point with earthing for AC, geyser or EV charger',
        priceMinor: 39900, // ₹399
        durationMinutes: 60,
        icon: Icons.cable_rounded,
      ),
    ],
    'hvac': [
      SubServiceItem(
        id: 'hvac-1',
        categorySlug: 'hvac',
        name: 'AC Jet Foam Deep Service',
        description: 'High-pressure foam wash for cooling coil, blower & filters',
        priceMinor: 49900, // ₹499
        durationMinutes: 60,
        icon: Icons.ac_unit_rounded,
        badge: 'BESTSELLER',
      ),
      SubServiceItem(
        id: 'hvac-2',
        categorySlug: 'hvac',
        name: 'AC Water Leakage & Drain Clear',
        description: 'Unclog condensate drain pipe and fix indoor unit tray tilt',
        priceMinor: 39900, // ₹399
        durationMinutes: 45,
        icon: Icons.water_damage_rounded,
      ),
      SubServiceItem(
        id: 'hvac-3',
        categorySlug: 'hvac',
        name: 'Refrigerant Gas Leak Check & Top-up',
        description: 'Nitrogen pressure testing, flare nut tightening and gas charge',
        priceMinor: 79900, // ₹799
        durationMinutes: 75,
        icon: Icons.speed_rounded,
      ),
    ],
    'appliance-repair': [
      SubServiceItem(
        id: 'app-1',
        categorySlug: 'appliance-repair',
        name: 'Refrigerator Cooling & Defrost Fix',
        description: 'Thermostat inspection, cooling coil defrost timer & fan motor',
        priceMinor: 19900, // ₹199
        durationMinutes: 45,
        icon: Icons.kitchen_rounded,
        badge: 'POPULAR',
      ),
      SubServiceItem(
        id: 'app-2',
        categorySlug: 'appliance-repair',
        name: 'Washing Machine Drum / Drain Repair',
        description: 'Belt replacement, water drain pump unblocking & suspension rods',
        priceMinor: 29900, // ₹299
        durationMinutes: 50,
        icon: Icons.local_laundry_service_rounded,
      ),
      SubServiceItem(
        id: 'app-3',
        categorySlug: 'appliance-repair',
        name: 'Microwave Heating / Turntable Fix',
        description: 'Magnetron check, fuse replacement, roller ring repair',
        priceMinor: 24900, // ₹249
        durationMinutes: 40,
        icon: Icons.microwave_rounded,
      ),
    ],
    'cleaning': [
      SubServiceItem(
        id: 'clean-1',
        categorySlug: 'cleaning',
        name: 'Bathroom Deep Cleaning',
        description: 'Hard water scale removal, tiles scrub, grout & sanitary sanitization',
        priceMinor: 49900, // ₹499
        durationMinutes: 90,
        icon: Icons.bathtub_rounded,
        badge: 'TOP RATED',
      ),
      SubServiceItem(
        id: 'clean-2',
        categorySlug: 'cleaning',
        name: 'Kitchen Chimney & Counter Degrease',
        description: 'Exhaustive grease removal from chimney filters, stove & tiles',
        priceMinor: 59900, // ₹599
        durationMinutes: 120,
        icon: Icons.countertops_rounded,
      ),
      SubServiceItem(
        id: 'clean-3',
        categorySlug: 'cleaning',
        name: 'Sofa & Upholstery Shampooing',
        description: 'Deep extraction vacuuming & stain treatment per 3-seater sofa',
        priceMinor: 69900, // ₹699
        durationMinutes: 90,
        icon: Icons.chair_rounded,
      ),
    ],
    'locksmith': [
      SubServiceItem(
        id: 'lock-1',
        categorySlug: 'locksmith',
        name: 'Door Lock Installation & Repair',
        description: 'Mortise lock, cylinder replacement, alignment fixing',
        priceMinor: 24900, // ₹249
        durationMinutes: 45,
        icon: Icons.lock_outline_rounded,
      ),
      SubServiceItem(
        id: 'lock-2',
        categorySlug: 'locksmith',
        name: 'Emergency Lockout Assistance',
        description: 'Rapid door unlock without destructive door damage',
        priceMinor: 39900, // ₹399
        durationMinutes: 30,
        icon: Icons.key_rounded,
        badge: 'URGENT',
      ),
    ],
    'handyman': [
      SubServiceItem(
        id: 'handy-1',
        categorySlug: 'handyman',
        name: 'Wall Drill & Photo / Mirror Hanging',
        description: 'Up to 3 items hung securely with rawl plugs & screws',
        priceMinor: 14900, // ₹149
        durationMinutes: 30,
        icon: Icons.home_repair_service_rounded,
      ),
      SubServiceItem(
        id: 'handy-2',
        categorySlug: 'handyman',
        name: 'Flat-Pack Furniture Assembly',
        description: 'Bed, wardrobe, bookshelf, or table assembly according to manual',
        priceMinor: 34900, // ₹349
        durationMinutes: 60,
        icon: Icons.handyman_rounded,
      ),
    ],
  };

  static List<SubServiceItem> _defaultFallback(String slug) => [
        SubServiceItem(
          id: '$slug-gen-1',
          categorySlug: slug,
          name: 'Standard Diagnostic Inspection',
          description: 'On-site technician visit, problem assessment & immediate minor fix',
          priceMinor: 14900,
          durationMinutes: 45,
          icon: Icons.build_circle_rounded,
        ),
        SubServiceItem(
          id: '$slug-gen-2',
          categorySlug: slug,
          name: 'Comprehensive Repair Service',
          description: 'Full servicing, wear-and-tear replacement & safety check',
          priceMinor: 29900,
          durationMinutes: 75,
          icon: Icons.handyman_rounded,
        ),
      ];
}
