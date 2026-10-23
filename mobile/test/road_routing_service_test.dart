import 'dart:convert';
import 'package:fixnow_mobile/features/tracking/road_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RoadRoutingService', () {
    test('successfully parses OpenRouteService GeoJSON driving response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('openrouteservice.org')) {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'summary': {'distance': 3450.0, 'duration': 480},
                  },
                  'geometry': {
                    'coordinates': [
                      [72.99, 22.89],
                      [73.00, 22.90],
                      [73.01, 22.91],
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = RoadRoutingService(client: mockClient);
      final route = await service.getRoadRoute(
        originLat: 22.89,
        originLng: 72.99,
        destLat: 22.91,
        destLng: 73.01,
      );

      expect(route, isNotNull);
      expect(route!.distanceMeters, 3450.0);
      expect(route.durationSeconds, 480);
      expect(route.coordinates.length, 3);
      expect(route.coordinates.first.latitude, 22.89);
      expect(route.coordinates.first.longitude, 72.99);
      expect(route.coordinates.last.latitude, 22.91);
      expect(route.coordinates.last.longitude, 73.01);
    });

    test('resiliently falls back to OSRM when OpenRouteService fails (429/error)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('openrouteservice.org')) {
          return http.Response('Rate Limit Exceeded', 429);
        }
        if (request.url.host.contains('project-osrm.org')) {
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'distance': 3600.0,
                  'duration': 510,
                  'geometry': {
                    'coordinates': [
                      [72.99, 22.89],
                      [73.005, 22.905],
                      [73.01, 22.91],
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = RoadRoutingService(client: mockClient);
      final route = await service.getRoadRoute(
        originLat: 22.89,
        originLng: 72.99,
        destLat: 22.91,
        destLng: 73.01,
      );

      expect(route, isNotNull);
      expect(route!.distanceMeters, 3600.0);
      expect(route.durationSeconds, 510);
      expect(route.coordinates.length, 3);
    });

    test('reuses cached route within distance and age threshold', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'summary': {'distance': 1500.0, 'duration': 300},
                },
                'geometry': {
                  'coordinates': [
                    [72.99, 22.89],
                    [73.00, 22.90],
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RoadRoutingService(client: mockClient);
      // First fetch
      final first = await service.getRoadRoute(
        originLat: 22.89000,
        originLng: 72.99000,
        destLat: 22.90000,
        destLng: 73.00000,
      );
      expect(first, isNotNull);

      // Micro drift of ~10 meters should reuse cache without making extra request
      final second = await service.getRoadRoute(
        originLat: 22.89008,
        originLng: 72.99008,
        destLat: 22.90000,
        destLng: 73.00000,
      );

      expect(second, same(first));
      expect(requestCount, 1);
    });

    test('collapses in-flight concurrent requests for same destination', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'summary': {'distance': 2000.0, 'duration': 400},
                },
                'geometry': {
                  'coordinates': [
                    [72.99, 22.89],
                    [73.00, 22.90],
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RoadRoutingService(client: mockClient);
      final results = await Future.wait([
        service.getRoadRoute(
          originLat: 22.89,
          originLng: 72.99,
          destLat: 22.90,
          destLng: 73.00,
        ),
        service.getRoadRoute(
          originLat: 22.89,
          originLng: 72.99,
          destLat: 22.90,
          destLng: 73.00,
        ),
      ]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(requestCount, 1);
    });
  });
}
