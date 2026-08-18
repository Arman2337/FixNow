import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum BookingLocationFailureKind {
  servicesDisabled,
  permissionDenied,
  unavailable,
  stale,
  inaccurate,
}

class BookingLocationFailure implements Exception {
  const BookingLocationFailure(this.kind, this.message);

  final BookingLocationFailureKind kind;
  final String message;
}

class BookingLocationFix {
  const BookingLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

abstract interface class BookingLocationProvider {
  Future<BookingLocationFix> resolve();
}

abstract interface class BookingLocationGateway {
  Future<bool> isServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<BookingLocationFix> current();

  Future<BookingLocationFix?> lastKnown();
}

class GeolocatorBookingLocationGateway implements BookingLocationGateway {
  const GeolocatorBookingLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<BookingLocationFix> current() async => _fromPosition(
    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    ),
  );

  @override
  Future<BookingLocationFix?> lastKnown() async {
    if (kIsWeb) return null;
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : _fromPosition(position);
    } catch (_) {
      return null;
    }
  }

  BookingLocationFix _fromPosition(Position position) => BookingLocationFix(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
    timestamp: position.timestamp,
  );
}

class BookingLocationResolver implements BookingLocationProvider {
  BookingLocationResolver({
    BookingLocationGateway? gateway,
    DateTime Function()? now,
    this.maxAge = const Duration(minutes: 2),
    this.maxAccuracyMeters = 5000,
  }) : _gateway = gateway ?? const GeolocatorBookingLocationGateway(),
       _now = now ?? DateTime.now;

  final BookingLocationGateway _gateway;
  final DateTime Function() _now;
  final Duration maxAge;
  final double maxAccuracyMeters;

  @override
  Future<BookingLocationFix> resolve() async {
    try {
      if (!await _gateway.isServiceEnabled()) {
        throw const BookingLocationFailure(
          BookingLocationFailureKind.servicesDisabled,
          'Turn on Location Services to request nearby help.',
        );
      }

      var permission = await _gateway.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _gateway.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const BookingLocationFailure(
          BookingLocationFailureKind.permissionDenied,
          'Location access is needed to match providers near you.',
        );
      }

      try {
        final current = await _gateway.current();
        if (_isUsable(current)) return current;
        debugPrint('Location fix rejected. Accuracy: ${current.accuracyMeters}m (Max allowed: ${maxAccuracyMeters}m)');
      } catch (e, stackTrace) {
        debugPrint('Geolocator.getCurrentPosition failed: $e\n$stackTrace');
      }

      final fallback = await _gateway.lastKnown();
      if (fallback == null) {
        throw const BookingLocationFailure(
          BookingLocationFailureKind.unavailable,
          'We could not get your location. Move to an open area and try again.',
        );
      }
      if (!_isFresh(fallback)) {
        throw const BookingLocationFailure(
          BookingLocationFailureKind.stale,
          'Your last location is too old. Move to an open area and try again.',
        );
      }
      if (!_isAccurate(fallback)) {
        throw const BookingLocationFailure(
          BookingLocationFailureKind.inaccurate,
          'Your location is not accurate enough. Move to an open area and try again.',
        );
      }
      return fallback;
    } on BookingLocationFailure {
      rethrow;
    } catch (e) {
      throw BookingLocationFailure(
        BookingLocationFailureKind.unavailable,
        'Location error: $e',
      );
    }
  }

  bool _isUsable(BookingLocationFix fix) => _isFresh(fix) && _isAccurate(fix);

  bool _isFresh(BookingLocationFix fix) {
    final age = _now().toUtc().difference(fix.timestamp.toUtc());
    return age >= Duration.zero && age <= maxAge;
  }

  bool _isAccurate(BookingLocationFix fix) =>
      fix.accuracyMeters.isFinite &&
      fix.accuracyMeters >= 0 &&
      fix.accuracyMeters <= maxAccuracyMeters;
}
