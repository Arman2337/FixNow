import 'dart:convert';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LiveLocationService {
  const LiveLocationService._();

  /// Requests permission if needed, resolves live GPS coordinates, performs
  /// reverse geocoding across platforms, and stores the resulting address in
  /// [SavedAddressRepository] as default.
  static Future<SavedAddress?> detectAndSaveLiveAddress({
    bool skipPermissionCheck = false,
  }) async {
    try {
      if (!skipPermissionCheck) {
        try {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm != LocationPermission.whileInUse &&
              perm != LocationPermission.always) {
            return null;
          }

          final isEnabled = await Geolocator.isLocationServiceEnabled();
          if (!isEnabled) return null;
        } on UnimplementedError {
          // Allow mock platforms in tests without permission APIs
        } catch (_) {
          // If permission check failed, still attempt to get position
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: const Duration(seconds: 5),
                maximumAge: const Duration(minutes: 5),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
      );

      String? locality;
      String? city;
      String? state;
      String? postalCode;
      String? street;

      if (kIsWeb) {
        try {
          final placemarks = await Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 3));
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            street = p.street;
            locality = p.subLocality ?? p.locality;
            city = p.locality ?? p.subAdministrativeArea;
            state = p.administrativeArea ?? p.country;
            postalCode = p.postalCode;
          }
        } catch (_) {
          try {
            final uri = Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
            );
            final response =
                await http.get(uri).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              locality = data['locality']?.toString();
              city = data['city']?.toString() ?? locality;
              state = data['principalSubdivision']?.toString() ??
                  data['countryName']?.toString();
              postalCode = data['postcode']?.toString();
            }
          } catch (e) {
            debugPrint('Web geocoding fallback failed: $e');
          }
        }
      } else {
        try {
          final placemarks = await Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 3));
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            street = p.street;
            locality = p.subLocality ?? p.locality;
            city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
            state = p.administrativeArea ?? p.country;
            postalCode = p.postalCode;
          }
        } catch (_) {
          try {
            final uri = Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
            );
            final response =
                await http.get(uri).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              locality = data['locality']?.toString();
              city = data['city']?.toString() ?? locality;
              state = data['principalSubdivision']?.toString() ??
                  data['countryName']?.toString();
              postalCode = data['postcode']?.toString();
            }
          } catch (_) {}
        }
      }

      final effectiveCity =
          (city != null && city.trim().isNotEmpty) ? city.trim() : 'Local Area';
      final parts = [
        if (locality != null &&
            locality.trim().isNotEmpty &&
            locality != effectiveCity)
          locality.trim(),
        if (street != null && street.trim().isNotEmpty && street != locality)
          street.trim(),
        if (state != null &&
            state.trim().isNotEmpty &&
            (locality == null || locality.isEmpty))
          state.trim(),
      ];
      final area =
          parts.isNotEmpty ? parts.join(', ') : (state ?? 'Current Area');

      final liveAddress = SavedAddress(
        id: 'addr-current-live',
        label: AddressLabel.other,
        customTitle: 'Current Location',
        flatBuilding: (street != null && street.trim().isNotEmpty && street.trim() != area)
            ? street.trim()
            : 'Current Location',
        streetArea: area,
        city: effectiveCity,
        postalCode: postalCode ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
        isDefault: true,
      );

      SavedAddressRepository.instance.saveAddress(liveAddress);
      return liveAddress;
    } catch (e) {
      debugPrint('LiveLocationService error: $e');
      return null;
    }
  }
}
