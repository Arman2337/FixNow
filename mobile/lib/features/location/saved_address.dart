import 'package:flutter/material.dart';

enum AddressLabel { home, work, other }

/// A customer's saved address for 1-tap booking address selection.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.customTitle,
    required this.flatBuilding,
    required this.streetArea,
    this.landmark,
    this.city = 'Bengaluru',
    this.postalCode = '560034',
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  final String id;
  final AddressLabel label;
  final String customTitle;
  final String flatBuilding;
  final String streetArea;
  final String? landmark;
  final String city;
  final String postalCode;
  final double latitude;
  final double longitude;
  final bool isDefault;

  IconData get icon => switch (label) {
        AddressLabel.home => Icons.home_rounded,
        AddressLabel.work => Icons.work_rounded,
        AddressLabel.other => Icons.location_on_rounded,
      };

  String get labelText => switch (label) {
        AddressLabel.home => 'Home',
        AddressLabel.work => 'Work',
        AddressLabel.other => customTitle.isNotEmpty ? customTitle : 'Other',
      };

  String get formattedSnippet => '$flatBuilding, $streetArea';

  String get formattedFull =>
      '$flatBuilding, $streetArea${landmark != null && landmark!.isNotEmpty ? ' (Near $landmark)' : ''}, $city - $postalCode';

  SavedAddress copyWith({
    String? id,
    AddressLabel? label,
    String? customTitle,
    String? flatBuilding,
    String? streetArea,
    String? landmark,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) =>
      SavedAddress(
        id: id ?? this.id,
        label: label ?? this.label,
        customTitle: customTitle ?? this.customTitle,
        flatBuilding: flatBuilding ?? this.flatBuilding,
        streetArea: streetArea ?? this.streetArea,
        landmark: landmark ?? this.landmark,
        city: city ?? this.city,
        postalCode: postalCode ?? this.postalCode,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        isDefault: isDefault ?? this.isDefault,
      );
}

/// In-memory repository for managing saved customer addresses.
class SavedAddressRepository extends ChangeNotifier {
  SavedAddressRepository._() {
    _seedDefaults();
  }
  static final SavedAddressRepository instance = SavedAddressRepository._();

  final List<SavedAddress> _addresses = [];

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);

  SavedAddress? get defaultAddress {
    if (_addresses.isEmpty) return null;
    return _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first);
  }

  void _seedDefaults() {
    _addresses.addAll([
      const SavedAddress(
        id: 'addr-home-1',
        label: AddressLabel.home,
        customTitle: 'Home',
        flatBuilding: 'Flat 402, Lotus Heights',
        streetArea: '4th Cross, Koramangala 5th Block',
        landmark: 'Opposite Sony World Signal',
        city: 'Bengaluru',
        postalCode: '560034',
        latitude: 12.9352,
        longitude: 77.6245,
        isDefault: true,
      ),
      const SavedAddress(
        id: 'addr-work-2',
        label: AddressLabel.work,
        customTitle: 'Office',
        flatBuilding: 'Desk 5B, WeWork Galaxy',
        streetArea: '43 Residency Road, Shanthala Nagar',
        landmark: 'Near Mayo Hall Metro',
        city: 'Bengaluru',
        postalCode: '560025',
        latitude: 12.9719,
        longitude: 77.6070,
        isDefault: false,
      ),
    ]);
  }

  void saveAddress(SavedAddress address) {
    final idx = _addresses.indexWhere((a) => a.id == address.id);
    if (address.isDefault) {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
    if (idx >= 0) {
      _addresses[idx] = address;
    } else {
      _addresses.add(address);
    }
    notifyListeners();
  }

  void deleteAddress(String id) {
    _addresses.removeWhere((a) => a.id == id);
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    notifyListeners();
  }

  void setDefault(String id) {
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(isDefault: _addresses[i].id == id);
    }
    notifyListeners();
  }

  void reset() {
    _addresses.clear();
    _seedDefaults();
    notifyListeners();
  }
}
