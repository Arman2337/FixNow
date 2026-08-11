import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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
      _map(await Permission.locationWhenInUse.status);

  @override
  Future<LocationPermissionState> request() async =>
      _map(await Permission.locationWhenInUse.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  LocationPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return LocationPermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LocationPermissionState.permanentlyDenied;
    }
    if (status.isDenied) return LocationPermissionState.denied;
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
