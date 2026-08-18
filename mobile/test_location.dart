
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'lib/features/location/booking_location.dart';

class MockGateway implements BookingLocationGateway {
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;
  @override
  Future<BookingLocationFix> current() async => BookingLocationFix(
    latitude: 37.7749,
    longitude: -122.4194,
    accuracyMeters: 4500.0, // Simulate low accuracy desktop IP location
    timestamp: DateTime.now(),
  );
  @override
  Future<BookingLocationFix?> lastKnown() async => null;
}

void main() async {
  print('Testing BookingLocationResolver...');
  final resolver = BookingLocationResolver(
    gateway: MockGateway(),
    maxAccuracyMeters: 5000,
  );
  try {
    final fix = await resolver.resolve();
    print('SUCCESS! Resolved location: \, \ with accuracy \m');
  } catch (e) {
    print('FAILED: \');
  }
}
