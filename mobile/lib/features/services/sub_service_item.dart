import 'package:flutter/material.dart';
import 'package:fixnow_mobile/api/api_client.dart';

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
    this.imageUrl,
  });

  final String id;
  final String categorySlug;
  final String name;
  final String description;
  final int priceMinor; // in paise
  final int durationMinutes;
  final IconData icon;
  final String? badge;
  final String? imageUrl;

  String get formattedPrice {
    final rupees = priceMinor / 100;
    return '₹${rupees.toStringAsFixed(priceMinor % 100 == 0 ? 0 : 2)}';
  }

  String get formattedDuration => '$durationMinutes mins';

  static IconData resolveIcon(String name, String categorySlug) {
    final lower = name.toLowerCase();
    final cat = categorySlug.toLowerCase();

    if (lower.contains('tap') || lower.contains('mixer') || lower.contains('water') || lower.contains('tank')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('flush') || lower.contains('toilet') || lower.contains('commode') || lower.contains('jet spray')) {
      return Icons.sanitizer_rounded;
    }
    if (lower.contains('shower') || lower.contains('leak')) {
      return Icons.shower_rounded;
    }
    if (lower.contains('drain') || lower.contains('clog') || lower.contains('basin')) {
      return Icons.cleaning_services_rounded;
    }
    if (lower.contains('switch') || lower.contains('socket') || lower.contains('plug')) {
      return Icons.power_rounded;
    }
    if (lower.contains('fan') || lower.contains('light') || lower.contains('chandelier')) {
      return Icons.lightbulb_rounded;
    }
    if (lower.contains('mcb') || lower.contains('fuse') || lower.contains('wire') || lower.contains('short circuit')) {
      return Icons.flash_on_rounded;
    }
    if (cat.contains('hvac') || lower.contains('ac') || lower.contains('cooling')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('fridge') || lower.contains('refrigerator')) {
      return Icons.kitchen_rounded;
    }
    if (lower.contains('wash') || lower.contains('laundry')) {
      return Icons.local_laundry_service_rounded;
    }
    if (lower.contains('micro') || lower.contains('oven')) {
      return Icons.microwave_rounded;
    }
    if (lower.contains('bath')) {
      return Icons.bathtub_rounded;
    }
    if (lower.contains('chimney') || lower.contains('kitchen')) {
      return Icons.countertops_rounded;
    }
    if (lower.contains('sofa') || lower.contains('chair') || lower.contains('furniture') || lower.contains('bed')) {
      return Icons.chair_rounded;
    }
    if (lower.contains('lock') || lower.contains('key') || lower.contains('door')) {
      return Icons.lock_outline_rounded;
    }
    if (lower.contains('pest') || lower.contains('cockroach') || lower.contains('bug') || lower.contains('termite')) {
      return Icons.pest_control_rounded;
    }
    if (lower.contains('drill') || lower.contains('wall') || lower.contains('shelf')) {
      return Icons.home_repair_service_rounded;
    }
    return Icons.build_rounded;
  }
}

/// A line item in the customer's active service cart.
class CartItem {
  const CartItem({required this.subService, required this.quantity});

  final SubServiceItem subService;
  final int quantity;

  int get itemTotalMinor => subService.priceMinor * quantity;

  String get formattedTotal {
    final rupees = itemTotalMinor / 100;
    return '₹${rupees.toStringAsFixed(itemTotalMinor % 100 == 0 ? 0 : 2)}';
  }

  CartItem copyWith({int? quantity}) =>
      CartItem(subService: subService, quantity: quantity ?? this.quantity);
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

  int getQuantity(String subServiceId) => _items[subServiceId]?.quantity ?? 0;

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

class SubServiceRepository {
  const SubServiceRepository(this._api);
  final ApiTransport _api;

  Future<List<SubServiceItem>> getSubServicesForCategory(
    String categorySlug,
  ) async {
    try {
      final response = await _api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'sub-services?categoryId=$categorySlug',
        ),
      );

      final data = response.body;
      if (data is List && data.isNotEmpty) {
        return data.map((json) {
          final j = json as Map<String, dynamic>;
          final name = (j['name'] ?? '').toString();
          return SubServiceItem(
            id: j['id'] ?? '',
            categorySlug: categorySlug,
            name: name,
            description: j['description'] ?? '',
            priceMinor: j['priceMinor'] ?? 0,
            durationMinutes: j['estimatedDurationMinutes'] ?? 0,
            icon: SubServiceItem.resolveIcon(name, categorySlug),
            badge: j['badge'],
            imageUrl: j['imageUrl'],
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to local default catalog
    }
    return _fallbackSubServices(categorySlug);
  }

  static List<SubServiceItem> _fallbackSubServices(String categorySlug) {
    final slug = categorySlug.toLowerCase().replaceAll('_', '-');
    if (slug.contains('plumb')) {
      return const [
        SubServiceItem(
          id: 'plumb-tap',
          categorySlug: 'plumbing',
          name: 'Tap & Mixer Repair',
          description: 'Fix leaking, dripping, low-flow or stiff taps and mixers',
          priceMinor: 14900,
          durationMinutes: 30,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'plumb-toilet',
          categorySlug: 'plumbing',
          name: 'Flush Tank & Jet Spray Fix',
          description: 'Flush valve repair, continuous running water or commode seal',
          priceMinor: 49900,
          durationMinutes: 45,
          badge: 'Best Value',
        ),
        SubServiceItem(
          id: 'plumb-leak',
          categorySlug: 'plumbing',
          name: 'Pipe Leakage & Drainage Block',
          description: 'Sink siphon, wall seepage line or kitchen drain block resolution',
          priceMinor: 39900,
          durationMinutes: 45,
        ),
        SubServiceItem(
          id: 'plumb-tank',
          categorySlug: 'plumbing',
          name: 'Water Tank & Pipe Installation',
          description: 'Overhead tank connector fitting, motor inlet line overhaul',
          priceMinor: 89900,
          durationMinutes: 90,
        ),
      ];
    }

    if (slug.contains('electr')) {
      return const [
        SubServiceItem(
          id: 'elec-switch',
          categorySlug: 'electrical',
          name: 'Switch & Socket Replacement',
          description: 'Replace faulty switches, sockets, or master power points',
          priceMinor: 9900,
          durationMinutes: 20,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'elec-fan',
          categorySlug: 'electrical',
          name: 'Ceiling Fan Installation & Repair',
          description: 'Fix wobbling fan, capacitor change or new fan hanging',
          priceMinor: 24900,
          durationMinutes: 35,
        ),
        SubServiceItem(
          id: 'elec-mcb',
          categorySlug: 'electrical',
          name: 'MCB & Tripping Fault Fix',
          description: 'Tripping MCB diagnosis, fuse burn fix, short circuit check',
          priceMinor: 49900,
          durationMinutes: 45,
          badge: 'Emergency',
        ),
        SubServiceItem(
          id: 'elec-light',
          categorySlug: 'electrical',
          name: 'Room Lighting & Concealed Wiring',
          description: 'Chandelier, strip light or new point cabling installation',
          priceMinor: 79900,
          durationMinutes: 60,
        ),
      ];
    }

    if (slug.contains('hvac') || slug.contains('ac')) {
      return const [
        SubServiceItem(
          id: 'ac-service',
          categorySlug: 'hvac',
          name: 'AC Foam Jet Deep Cleaning',
          description: 'High-pressure foam cleaning of indoor coils & outdoor condenser wash',
          priceMinor: 49900,
          durationMinutes: 45,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'ac-gas',
          categorySlug: 'hvac',
          name: 'Gas Leak Check & Refill',
          description: 'Nitrogen pressure leak detection and authentic refrigerant charging',
          priceMinor: 149900,
          durationMinutes: 60,
          badge: 'Best Value',
        ),
        SubServiceItem(
          id: 'ac-install',
          categorySlug: 'hvac',
          name: 'AC Installation / Uninstallation',
          description: 'Split or window AC bracket mounting, copper pipe laying & testing',
          priceMinor: 99900,
          durationMinutes: 90,
        ),
      ];
    }

    if (slug.contains('appliance')) {
      return const [
        SubServiceItem(
          id: 'app-wash',
          categorySlug: 'appliance_repair',
          name: 'Washing Machine Repair',
          description: 'Drum not spinning, water drainage issue or vibration diagnostic',
          priceMinor: 39900,
          durationMinutes: 45,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'app-fridge',
          categorySlug: 'appliance_repair',
          name: 'Refrigerator Cooling Repair',
          description: 'Defrost issue, thermostat or compressor start relay check',
          priceMinor: 44900,
          durationMinutes: 45,
        ),
        SubServiceItem(
          id: 'app-oven',
          categorySlug: 'appliance_repair',
          name: 'Microwave Oven Servicing',
          description: 'No heating issue, touch keypad or turntable motor repair',
          priceMinor: 34900,
          durationMinutes: 30,
        ),
      ];
    }

    if (slug.contains('carpent')) {
      return const [
        SubServiceItem(
          id: 'carp-door',
          categorySlug: 'carpenter',
          name: 'Door Lock & Latch Fitting',
          description: 'Main door lock, latch, peephole or handle fitment and alignment',
          priceMinor: 24900,
          durationMinutes: 30,
        ),
        SubServiceItem(
          id: 'carp-furn',
          categorySlug: 'carpenter',
          name: 'Furniture Repair & Assembly',
          description: 'Bed, wardrobe, table assembly or hydraulic bed pump repair',
          priceMinor: 39900,
          durationMinutes: 60,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'carp-drill',
          categorySlug: 'carpenter',
          name: 'Curtain Rod & Shelf Installation',
          description: 'Wall hanging, curtain bracket, painting and shelf mounting',
          priceMinor: 29900,
          durationMinutes: 40,
        ),
      ];
    }

    if (slug.contains('clean')) {
      return const [
        SubServiceItem(
          id: 'clean-bath',
          categorySlug: 'cleaning',
          name: 'Bathroom Deep Cleaning',
          description: 'Acid-free tile scrubbing, lime scale removal and sanitization',
          priceMinor: 49900,
          durationMinutes: 60,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'clean-kitchen',
          categorySlug: 'cleaning',
          name: 'Kitchen Deep Cleaning',
          description: 'Chimney degreasing, slab scrubbing and cabinet interior cleaning',
          priceMinor: 69900,
          durationMinutes: 90,
        ),
        SubServiceItem(
          id: 'clean-home',
          categorySlug: 'cleaning',
          name: 'Full Home Deep Cleaning',
          description: 'Intensive floor buffing, vacuuming, window and door wipe-down',
          priceMinor: 149900,
          durationMinutes: 180,
          badge: 'Best Value',
        ),
      ];
    }

    if (slug.contains('lock')) {
      return const [
        SubServiceItem(
          id: 'lock-open',
          categorySlug: 'locksmith',
          name: 'Emergency Door Opening',
          description: 'Non-destructive rapid door unlocking for lockout situations',
          priceMinor: 39900,
          durationMinutes: 25,
          badge: 'Emergency',
        ),
        SubServiceItem(
          id: 'lock-install',
          categorySlug: 'locksmith',
          name: 'Digital & Deadbolt Lock Fitment',
          description: 'High security deadbolt or smart biometric lock installation',
          priceMinor: 69900,
          durationMinutes: 45,
          badge: 'Best Value',
        ),
        SubServiceItem(
          id: 'lock-key',
          categorySlug: 'locksmith',
          name: 'Lock Repair & Re-keying',
          description: 'Internal cylinder repair, stuck key extraction and re-keying',
          priceMinor: 24900,
          durationMinutes: 30,
        ),
      ];
    }

    if (slug.contains('pest')) {
      return const [
        SubServiceItem(
          id: 'pest-cockroach',
          categorySlug: 'pest_control',
          name: 'Cockroach & Ant Gel Treatment',
          description: 'Odorless herbal gel baiting across all kitchen corners and drain traps',
          priceMinor: 49900,
          durationMinutes: 45,
          badge: 'Most Popular',
        ),
        SubServiceItem(
          id: 'pest-bedbug',
          categorySlug: 'pest_control',
          name: 'Bed Bug Eradication Plan',
          description: '2-stage intensive chemical spray treatment with 90-day warranty',
          priceMinor: 99900,
          durationMinutes: 60,
        ),
        SubServiceItem(
          id: 'pest-termite',
          categorySlug: 'pest_control',
          name: 'Termite Deep Protection',
          description: 'Drill-fill-seal subterranean perimeter defense barrier',
          priceMinor: 129900,
          durationMinutes: 90,
          badge: 'Best Value',
        ),
      ];
    }

    final formattedName = categorySlug
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    return [
      SubServiceItem(
        id: '$categorySlug-standard',
        categorySlug: categorySlug,
        name: 'Standard $formattedName Service',
        description: 'Comprehensive inspection, fault diagnosis and repair',
        priceMinor: 29900,
        durationMinutes: 45,
        badge: 'Most Popular',
      ),
      SubServiceItem(
        id: '$categorySlug-comprehensive',
        categorySlug: categorySlug,
        name: 'Comprehensive Overhaul & Tuning',
        description: 'Complete inspection, part replacements and warranty tune-up',
        priceMinor: 69900,
        durationMinutes: 90,
        badge: 'Best Value',
      ),
    ];
  }

  Future<List<SubServiceItem>> getAllSubServices() async {
    try {
      final response = await _api.send(
        const ApiRequest(method: ApiMethod.get, path: 'sub-services'),
      );

      final data = response.body;
      if (data is List && data.isNotEmpty) {
        return data.map((json) {
          final j = json as Map<String, dynamic>;
          final name = (j['name'] ?? '').toString();
          final categoryId = (j['categoryId'] ?? '').toString();
          return SubServiceItem(
            id: j['id'] ?? '',
            categorySlug: categoryId,
            name: name,
            description: j['description'] ?? '',
            priceMinor: j['priceMinor'] ?? 0,
            durationMinutes: j['estimatedDurationMinutes'] ?? 0,
            icon: SubServiceItem.resolveIcon(name, categoryId),
            badge: j['badge'],
            imageUrl: j['imageUrl'],
          );
        }).toList();
      }
    } catch (e) {
      // Fallback below
    }
    return [
      ..._fallbackSubServices('plumbing'),
      ..._fallbackSubServices('electrical'),
      ..._fallbackSubServices('hvac'),
      ..._fallbackSubServices('carpentry'),
      ..._fallbackSubServices('cleaning'),
      ..._fallbackSubServices('painting'),
      ..._fallbackSubServices('locksmith'),
      ..._fallbackSubServices('pest_control'),
    ];
  }
}
