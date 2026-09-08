import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

CustomerMapLocation _point(double lat, double lng) =>
    CustomerMapLocation(latitude: lat, longitude: lng);

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
}
