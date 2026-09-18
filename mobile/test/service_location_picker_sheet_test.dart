import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/location/service_location_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FakeGeolocatorPlatform({this.permission = LocationPermission.denied});
  LocationPermission permission;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 12.9716,
    longitude: 77.5946,
    timestamp: DateTime.now(),
    accuracy: 9,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _ResetPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {}

void main() {
  setUp(() {
    GeolocatorPlatform.instance = _ResetPlatform();
  });

  testWidgets('without a fix the confirm stays disabled on the world view', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.denied,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ServiceLocationPickerSheet.show(context, initialLocation: null),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();

    // Permission denied: world view and the confirm button disabled — the
    // sheet can never hand back the default view center as a booking
    // location.
    expect(find.text('Tap the map to place your pin'), findsOneWidget);
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tap the map to place your pin'),
    );
    expect(disabled.onPressed, isNull);
  });

  testWidgets('confirms the real GPS fix when permission is granted', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.whileInUse,
    );
    BookingLocationFix? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await ServiceLocationPickerSheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The resolver's GPS fix arms the confirm button without interaction.
    expect(find.text('Use this service location'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Use this service location'),
    );
    await tester.pumpAndSettle();

    // The returned fix is the device fix — not the world-view default.
    expect(picked, isNotNull);
    expect(picked!.latitude, 12.9716);
    expect(picked!.longitude, 77.5946);
  });
}
