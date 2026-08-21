import 'dart:async';

import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 10);

  test('prefers a fresh accurate foreground fix', () async {
    final gateway = _Gateway(
      currentFix: _fix(now.subtract(const Duration(seconds: 5))),
      lastFix: _fix(now.subtract(const Duration(seconds: 30)), latitude: 2),
    );

    final result = await _resolver(gateway).resolve();

    expect(result.latitude, 1);
    expect(gateway.lastKnownCalls, 0);
  });

  test(
    'uses a fresh accurate last-known fix after foreground timeout',
    () async {
      final gateway = _Gateway(
        currentError: TimeoutException('no fix'),
        lastFix: _fix(now.subtract(const Duration(seconds: 30)), latitude: 2),
      );

      final result = await _resolver(gateway).resolve();

      expect(result.latitude, 2);
      expect(gateway.lastKnownCalls, 1);
    },
  );

  test('uses a fresh Home fix before requesting location again', () async {
    final gateway = _Gateway(currentError: TimeoutException('no fix'));
    final homeFix = _fix(
      now.subtract(const Duration(seconds: 30)),
      latitude: 2,
    );

    final result = await BookingLocationResolver(
      gateway: gateway,
      now: () => now,
      initialFix: homeFix,
    ).resolve();

    expect(result.latitude, 2);
    expect(gateway.currentCalls, 0);
    expect(gateway.lastKnownCalls, 0);
  });

  test(
    'uses a recent Home fix when the browser cannot provide a new fix',
    () async {
      final gateway = _Gateway(currentError: TimeoutException('no fix'));
      final homeFix = _fix(
        now.subtract(const Duration(minutes: 20)),
        latitude: 2,
      );

      final result = await BookingLocationResolver(
        gateway: gateway,
        now: () => now,
        initialFix: homeFix,
      ).resolve();

      expect(result.latitude, 2);
      expect(gateway.currentCalls, 0);
    },
  );

  test('rejects disabled services and does not request a fix', () async {
    final gateway = _Gateway(servicesEnabled: false);

    await expectLater(
      _resolver(gateway).resolve(),
      throwsA(_failure(BookingLocationFailureKind.servicesDisabled)),
    );
    expect(gateway.currentCalls, 0);
    expect(gateway.lastKnownCalls, 0);
  });

  test('rejects denied permission and does not request a fix', () async {
    final gateway = _Gateway(permission: LocationPermission.deniedForever);

    await expectLater(
      _resolver(gateway).resolve(),
      throwsA(_failure(BookingLocationFailureKind.permissionDenied)),
    );
    expect(gateway.currentCalls, 0);
    expect(gateway.lastKnownCalls, 0);
  });

  test('rejects unavailable last-known data', () async {
    final gateway = _Gateway(currentError: StateError('unavailable'));

    await expectLater(
      _resolver(gateway).resolve(),
      throwsA(_failure(BookingLocationFailureKind.unavailable)),
    );
  });

  test('gives browser-specific guidance when no fix is available', () async {
    final gateway = _Gateway(currentError: TimeoutException('no fix'));

    await expectLater(
      _resolver(gateway, isWeb: true).resolve(),
      throwsA(
        predicate<Object?>(
          (value) =>
              value is BookingLocationFailure &&
              value.kind == BookingLocationFailureKind.unavailable &&
              value.message ==
                  'Your browser could not provide a precise location. Choose your service location on the map to continue.',
        ),
      ),
    );
  });

  test('rejects stale last-known data', () async {
    final gateway = _Gateway(
      currentError: TimeoutException('no fix'),
      lastFix: _fix(now.subtract(const Duration(minutes: 3))),
    );

    await expectLater(
      _resolver(gateway).resolve(),
      throwsA(_failure(BookingLocationFailureKind.stale)),
    );
  });

  test('rejects inaccurate last-known data', () async {
    final gateway = _Gateway(
      currentError: TimeoutException('no fix'),
      lastFix: _fix(now.subtract(const Duration(seconds: 30)), accuracy: 101),
    );

    await expectLater(
      _resolver(gateway).resolve(),
      throwsA(_failure(BookingLocationFailureKind.inaccurate)),
    );
  });

  test(
    'does not accept a foreground fix outside the freshness policy',
    () async {
      final gateway = _Gateway(
        currentFix: _fix(now.subtract(const Duration(minutes: 3))),
        lastFix: _fix(now.subtract(const Duration(minutes: 3))),
      );

      await expectLater(
        _resolver(gateway).resolve(),
        throwsA(_failure(BookingLocationFailureKind.stale)),
      );
    },
  );
}

BookingLocationResolver _resolver(_Gateway gateway, {bool? isWeb}) =>
    BookingLocationResolver(
      gateway: gateway,
      now: () => DateTime.utc(2026, 8, 15, 10),
      isWeb: isWeb,
    );

BookingLocationFix _fix(
  DateTime timestamp, {
  double latitude = 1,
  double accuracy = 10,
}) => BookingLocationFix(
  latitude: latitude,
  longitude: 3,
  accuracyMeters: accuracy,
  timestamp: timestamp,
);

Matcher _failure(BookingLocationFailureKind kind) => predicate<Object?>(
  (value) => value is BookingLocationFailure && value.kind == kind,
);

class _Gateway implements BookingLocationGateway {
  _Gateway({
    this.servicesEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.currentFix,
    this.currentError,
    this.lastFix,
  });

  final bool servicesEnabled;
  final LocationPermission permission;
  final BookingLocationFix? currentFix;
  final Object? currentError;
  final BookingLocationFix? lastFix;
  int currentCalls = 0;
  int lastKnownCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<BookingLocationFix> current() async {
    currentCalls++;
    if (currentError case final error?) throw error;
    return currentFix!;
  }

  @override
  Future<BookingLocationFix?> lastKnown() async {
    lastKnownCalls++;
    return lastFix;
  }
}
