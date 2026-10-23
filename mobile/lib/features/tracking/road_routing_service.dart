import 'dart:convert';
import 'dart:math' as math;

import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:http/http.dart' as http;

class RoadRouteCacheEntry {
  RoadRouteCacheEntry({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.timestamp,
    required this.route,
  });

  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final DateTime timestamp;
  final DrivingRoute route;
}

/// Service providing road-network driving route geometry, distance, and duration
/// with multi-engine resilience (OpenRouteService + OpenStreetMap OSRM fallback)
/// and intelligent in-memory distance/time caching to prevent GPS-polling API storms.
class RoadRoutingService {
  RoadRoutingService({http.Client? client}) : _client = client ?? http.Client();

  static final RoadRoutingService instance = RoadRoutingService();

  final http.Client _client;
  final Map<String, RoadRouteCacheEntry> _cache = {};
  final Map<String, Future<DrivingRoute?>> _inFlight = {};

  static const String _defaultOrsKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQzOWUxYTg5ZWQ1ZTRmZTVhYzA2NjQ5ZmY1YzdjZDdhIiwiaCI6Im11cm11cjY0In0=';

  /// Obtains a real road-network route between the given origin and destination.
  /// If the origin has moved less than [minRefreshDistanceMeters] from a cached
  /// request within [maxCacheAge], the cached road route is reused immediately.
  Future<DrivingRoute?> getRoadRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    double minRefreshDistanceMeters = 50.0,
    Duration maxCacheAge = const Duration(minutes: 5),
  }) async {
    final destinationKey =
        '${destLat.toStringAsFixed(5)},${destLng.toStringAsFixed(5)}';
    final cached = _cache[destinationKey];

    if (cached != null) {
      final movedMeters = distanceMeters(
        cached.originLat,
        cached.originLng,
        originLat,
        originLng,
      );
      final age = DateTime.now().difference(cached.timestamp);
      if (movedMeters < minRefreshDistanceMeters && age < maxCacheAge) {
        return cached.route;
      }
    }

    final inFlightRequest = _inFlight[destinationKey];
    if (inFlightRequest != null) {
      return inFlightRequest;
    }

    final request = _fetchRoadRouteWithFallback(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    _inFlight[destinationKey] = request;

    try {
      final route = await request;
      if (route != null && route.coordinates.length >= 2) {
        _cache[destinationKey] = RoadRouteCacheEntry(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
          timestamp: DateTime.now(),
          route: route,
        );
        return route;
      }
      return cached?.route;
    } finally {
      _inFlight.remove(destinationKey);
    }
  }

  Future<DrivingRoute?> _fetchRoadRouteWithFallback({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // 1. Primary Engine: OpenRouteService
    try {
      final orsUrl = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
      );
      final orsResponse = await _client
          .post(
            orsUrl,
            headers: {
              'Authorization': _defaultOrsKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [originLng, originLat],
                [destLng, destLat],
              ],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (orsResponse.statusCode == 200) {
        final data = jsonDecode(orsResponse.body) as Map<String, dynamic>;
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final feature = features.first as Map;
          final properties = feature['properties'] as Map?;
          final summary = properties?['summary'] as Map?;
          final geometry = feature['geometry'] as Map?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            final points = coords.map((p) {
              final raw = p as List;
              return CustomerMapLocation(
                longitude: (raw[0] as num).toDouble(),
                latitude: (raw[1] as num).toDouble(),
              );
            }).toList();
            return DrivingRoute(
              distanceMeters: (summary?['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (summary?['duration'] as num?)?.toInt() ?? 0,
              coordinates: points,
            );
          }
        }
      }
    } catch (_) {
      // Fall through to OSRM fallback engine
    }

    // 2. Resilient Fallback Engine: Open Source Routing Machine (OSRM)
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$originLng,$originLat;$destLng,$destLat?overview=full&geometries=geojson',
      );
      final osrmResponse = await _client
          .get(osrmUrl, headers: {'User-Agent': 'FixNow-Mobile/1.0'})
          .timeout(const Duration(seconds: 5));

      if (osrmResponse.statusCode == 200) {
        final data = jsonDecode(osrmResponse.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final first = routes.first as Map;
          final distance = (first['distance'] as num?)?.toDouble() ?? 0;
          final duration = (first['duration'] as num?)?.toInt() ?? 0;
          final geometry = first['geometry'] as Map?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            final points = coords.map((p) {
              final raw = p as List;
              return CustomerMapLocation(
                longitude: (raw[0] as num).toDouble(),
                latitude: (raw[1] as num).toDouble(),
              );
            }).toList();
            return DrivingRoute(
              distanceMeters: distance,
              durationSeconds: duration,
              coordinates: points,
            );
          }
        }
      }
    } catch (_) {
      // Ignore network errors, return null for graceful handling
    }

    return null;
  }

  /// Calculates great-circle distance in meters between two coordinates.
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const toRadians = math.pi / 180;
    final dLat = (lat2 - lat1) * toRadians;
    final dLon = (lon2 - lon1) * toRadians;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * toRadians) *
            math.cos(lat2 * toRadians) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * 6371000 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
