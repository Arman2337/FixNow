import 'package:flutter/material.dart';
import 'package:fixnow_mobile/api/api_client.dart';

class MockApiTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: []);
}

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

  String get formattedSnippet {
    final parts = [flatBuilding, streetArea].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String get formattedFull {
    final areaPart = [
      flatBuilding,
      streetArea,
      if (landmark != null && landmark!.trim().isNotEmpty) '(Near $landmark)',
    ].where((s) => s.trim().isNotEmpty).toList();

    final cityZip = [
      if (city.trim().isNotEmpty && postalCode.trim().isNotEmpty)
        '$city - $postalCode'
      else ...[
        if (city.trim().isNotEmpty) city,
        if (postalCode.trim().isNotEmpty) postalCode,
      ],
    ];

    return [...areaPart, ...cityZip].join(', ');
  }

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
  }) => SavedAddress(
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
  SavedAddressRepository({required this.api, required this.accessToken}) {
    _instance = this;
  }

  factory SavedAddressRepository.test() {
    return SavedAddressRepository(
      api: MockApiTransport(),
      accessToken: () async => '',
    );
  }

  static SavedAddressRepository? _instance;

  static SavedAddressRepository get instance {
    if (_instance == null) {
      debugPrint(
        'WARNING: SavedAddressRepository.instance was null. Falling back to test instance.',
      );
      _instance = SavedAddressRepository.test();
    }
    return _instance!;
  }

  final ApiTransport api;
  final Future<String?> Function() accessToken;

  List<SavedAddress> _addresses = [];
  bool _isLoading = false;

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);
  bool get isLoading => _isLoading;

  SavedAddress? get defaultAddress {
    if (_addresses.isEmpty) return null;
    return _addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => _addresses.first,
    );
  }

  void setUserId(String userId) {
    // legacy
  }

  Future<String> _requireToken() async {
    final token = await accessToken();
    if (token == null)
      throw const ApiException(ApiFailureKind.unauthorized, 'Not signed in');
    return token;
  }

  Future<void> fetchAddresses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await _requireToken();
      final response = await api.send(
        ApiRequest(
          method: ApiMethod.get,
          path: 'users/me/addresses',
          bearerToken: token,
        ),
      );

      final data = response.body as List<dynamic>;
      _addresses = data.map((json) {
        final j = json as Map<String, dynamic>;
        return SavedAddress(
          id: j['id'],
          label: j['label'] == 'Work'
              ? AddressLabel.work
              : (j['label'] == 'Home' ? AddressLabel.home : AddressLabel.other),
          customTitle: j['label'] ?? '',
          flatBuilding: j['street'],
          streetArea: j['street'], // simplify mapping
          city: j['city'] ?? 'Bengaluru',
          postalCode: j['zip'] ?? '560001',
          latitude: j['latitude'] is String
              ? double.tryParse(j['latitude']) ?? 0.0
              : (j['latitude']?.toDouble() ?? 0.0),
          longitude: j['longitude'] is String
              ? double.tryParse(j['longitude']) ?? 0.0
              : (j['longitude']?.toDouble() ?? 0.0),
          isDefault: j['isDefault'] ?? false,
        );
      }).toList();
    } catch (e) {
      // Ignore
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveAddress(SavedAddress address) async {
    try {
      final token = await _requireToken();
      await api.send(
        ApiRequest(
          method: ApiMethod.post,
          path: 'users/me/addresses',
          bearerToken: token,
          body: {
            'label': address.label == AddressLabel.work
                ? 'Work'
                : (address.label == AddressLabel.home
                      ? 'Home'
                      : address.customTitle),
            'street': address.flatBuilding,
            'city': address.city,
            'zip': address.postalCode,
            'latitude': address.latitude,
            'longitude': address.longitude,
            'isDefault': address.isDefault,
          },
        ),
      );
      await fetchAddresses();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      final token = await _requireToken();
      await api.send(
        ApiRequest(
          method: ApiMethod.delete,
          path: 'users/me/addresses/$id',
          bearerToken: token,
        ),
      );
      await fetchAddresses();
    } catch (e) {
      // Ignore
    }
  }

  void setDefault(String id) {
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(isDefault: _addresses[i].id == id);
    }
    notifyListeners();
  }

  void reset() {
    _addresses.clear();
    notifyListeners();
  }
}
