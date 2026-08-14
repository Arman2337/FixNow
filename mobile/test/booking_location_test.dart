import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
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

  testWidgets('shows location guidance without calling booking API', (
    tester,
  ) async {
    final transport = _RecordingTransport();
    final controller = BookingController(
      BookingRepository(api: transport, accessToken: () async => 'token'),
    );
    final gateway = _Gateway(servicesEnabled: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRequestScreen(
          category: const ServiceCategory(
            id: 'category',
            name: 'Plumbing',
            slug: 'plumbing',
          ),
          controller: controller,
          locationProvider: BookingLocationResolver(
            gateway: gateway,
            now: () => now,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField),
      'Kitchen sink is leaking.',
    );
    await tester.tap(find.text('Find a verified provider'));
    await tester.pump();

    expect(
      find.text('Turn on Location Services to request nearby help.'),
      findsOneWidget,
    );
    expect(transport.requests, isEmpty);
  });
}

BookingLocationResolver _resolver(_Gateway gateway) => BookingLocationResolver(
  gateway: gateway,
  now: () => DateTime.utc(2026, 8, 15, 10),
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

class _RecordingTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return const ApiResponse(statusCode: 500, body: null);
  }
}
