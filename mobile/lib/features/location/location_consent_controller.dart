import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionState {
  unknown,
  checking,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

abstract interface class LocationPermissionGateway {
  Future<LocationPermissionState> check();
  Future<LocationPermissionState> request();
  Future<bool> openSettings();
}

class PlatformLocationPermissionGateway implements LocationPermissionGateway {
  const PlatformLocationPermissionGateway();

  @override
  Future<LocationPermissionState> check() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> request() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();

  LocationPermissionState _map(LocationPermission status) {
    if (status == LocationPermission.whileInUse || status == LocationPermission.always) {
      return LocationPermissionState.granted;
    }
    if (status == LocationPermission.deniedForever) {
      return LocationPermissionState.permanentlyDenied;
    }
    if (status == LocationPermission.denied) {
      return LocationPermissionState.denied;
    }
    return LocationPermissionState.unavailable;
  }
}

class LocationConsentController extends ChangeNotifier {
  LocationConsentController(this._gateway);
  final LocationPermissionGateway _gateway;
  LocationPermissionState state = LocationPermissionState.unknown;

  Future<void> check() async => _run(_gateway.check);
  Future<void> request() async => _run(_gateway.request);
  Future<void> openSettings() async => _gateway.openSettings();

  Future<void> _run(Future<LocationPermissionState> Function() action) async {
    state = LocationPermissionState.checking;
    notifyListeners();
    try {
      state = await action();
    } catch (_) {
      state = LocationPermissionState.unavailable;
    }
    notifyListeners();
  }
}
