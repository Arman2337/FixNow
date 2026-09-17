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

class SubServiceRepository {
  const SubServiceRepository(this._api);
  final ApiTransport _api;

  Future<List<SubServiceItem>> getSubServicesForCategory(String categorySlug) async {
    try {
      final response = await _api.send(ApiRequest(
        method: ApiMethod.get,
        path: 'sub-services?categoryId=$categorySlug',
      ));
      
      final data = response.body;
      if (data is List) {
        return data.map((json) {
          final j = json as Map<String, dynamic>;
          return SubServiceItem(
            id: j['id'],
            categorySlug: categorySlug,
            name: j['name'],
            description: j['description'] ?? '',
            priceMinor: j['priceMinor'] ?? 0,
            durationMinutes: j['estimatedDurationMinutes'] ?? 0,
            badge: j['badge'],
            imageUrl: j['imageUrl'],
          );
        }).toList();
      }
    } catch (e) {
      // Fallback to empty
    }
    return [];
  }

  Future<List<SubServiceItem>> getAllSubServices() async {
    try {
      final response = await _api.send(const ApiRequest(
        method: ApiMethod.get,
        path: 'sub-services',
      ));
      
      final data = response.body;
      if (data is List) {
        return data.map((json) {
          final j = json as Map<String, dynamic>;
          return SubServiceItem(
            id: j['id'],
            categorySlug: j['categoryId'],
            name: j['name'],
            description: j['description'] ?? '',
            priceMinor: j['priceMinor'] ?? 0,
            durationMinutes: j['estimatedDurationMinutes'] ?? 0,
            badge: j['badge'],
            imageUrl: j['imageUrl'],
          );
        }).toList();
      }
    } catch (e) {
      // Return empty list
    }
    return [];
  }
}
