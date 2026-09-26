import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

CustomerMapLocation _point(double lat, double lng) =>
    CustomerMapLocation(latitude: lat, longitude: lng);

ProviderMapLocation _tech(double lat, double lng) => ProviderMapLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 5,
      capturedAt: DateTime(2026, 9, 26, 10),
      receivedAt: DateTime(2026, 9, 26, 10),
    );

/// The camera of the single map on screen, read from a descendant context.
MapCamera _camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer).first));

Widget _map(WidgetTester tester, Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('sliceRoute', () {
    final threePoints = [_point(0, 0), _point(0, 10), _point(0, 20)];

    test('empty route and degenerate progress yield nothing', () {
      expect(sliceRoute(const [], 0.5), isEmpty);
      expect(sliceRoute(threePoints, 0), isEmpty);
      expect(sliceRoute(threePoints, -1), isEmpty);
    });

    test('t=1 returns every point', () {
      final sliced = sliceRoute(threePoints, 1);
      expect(sliced, hasLength(3));
      expect(sliced.last, const LatLng(0, 20));
    });

    test('mid single segment interpolates exactly', () {
      final sliced = sliceRoute(threePoints, 0.25);
      // 0.25 across a two-point span lands halfway through segment 1.
      expect(sliced, hasLength(2));
      expect(sliced.last.latitude, closeTo(0, 1e-9));
      expect(sliced.last.longitude, closeTo(5, 1e-9));
    });

    test(
      'progress crossing segments includes whole points plus the partial',
      () {
        final sliced = sliceRoute(threePoints, 0.75);
        // 0.75 * 2 spans = 1.5 → points 0, 1 whole + one interpolated half-seg.
        expect(sliced, hasLength(3));
        expect(sliced[1], const LatLng(0, 10));
        expect(sliced.last.longitude, closeTo(15, 1e-9));
      },
    );

    test('single point route yields just that point for any positive t', () {
      final single = [_point(1, 1)];
      expect(sliceRoute(single, 0.5), hasLength(1));
      expect(sliceRoute(single, 1), hasLength(1));
    });
  });

  group('viewport fit', () {
    // Regression: the cockpit embeds the map in a 110px strip. A constant
    // 40/56 padding made the fit box zero-height, the camera fell to zoom 0
    // and the tile layer drew the world five times over.
    testWidgets('short snippet keeps a street-level camera on both pins', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _map(
          tester,
          ProviderLiveMap(
            height: 110,
            showOverlay: false,
            providerLocation: _tech(23.0269, 73.0701),
            customerLocation: _point(23.0330, 73.0800),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final camera = _camera(tester);
      expect(camera.zoom, greaterThan(5));
      final visible = camera.visibleBounds;
      expect(visible.contains(const LatLng(23.0269, 73.0701)), isTrue);
      expect(visible.contains(const LatLng(23.0330, 73.0800)), isTrue);
    });

    testWidgets('tall map still fits both pins in view', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _map(
          tester,
          ProviderLiveMap(
            showOverlay: false,
            providerLocation: _tech(23.0269, 73.0701),
            customerLocation: _point(23.0330, 73.0800),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final visible = _camera(tester).visibleBounds;
      expect(visible.contains(const LatLng(23.0269, 73.0701)), isTrue);
      expect(visible.contains(const LatLng(23.0330, 73.0800)), isTrue);
    });

    testWidgets('two pins a few metres apart stay capped, not rooftop level', (
      tester,
    ) async {
      await tester.pumpWidget(
        _map(
          tester,
          ProviderLiveMap(
            showOverlay: false,
            providerLocation: _tech(23.02690, 73.07010),
            customerLocation: _point(23.02691, 73.07011),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, lessThanOrEqualTo(17.5));
    });
  });
}
