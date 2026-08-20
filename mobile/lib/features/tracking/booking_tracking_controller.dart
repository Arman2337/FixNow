import 'dart:async';

import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

class BookingTrackingController extends ChangeNotifier {
  BookingTrackingController({
    required this.bookingId,
    required this.source,
    this.realtime,
  });
  final String bookingId;
  final BookingTrackingSource source;
  final RealtimeClient? realtime;
  StreamSubscription<RealtimeProjection>? _projectionSubscription;
  TrackingConnection connection = TrackingConnection.connecting;
  BookingTracking? tracking;
  String? message;

  Future<void> loadSnapshot() async {
    connection = TrackingConnection.reconciling;
    notifyListeners();
    try {
      tracking = await source.fetchSnapshot(bookingId);
      _projectionSubscription ??= realtime?.projections.listen(
        _applyProjection,
      );
      await realtime?.subscribeBooking(bookingId);
      connection = TrackingConnection.live;
      message = null;
    } catch (_) {
      connection = TrackingConnection.offline;
      message = 'Tracking is temporarily unavailable.';
    }
    notifyListeners();
  }

  Future<void> _applyProjection(RealtimeProjection projection) async {
    final data = projection.data;
    final next = BookingTracking(
      bookingId: data['bookingId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      sequence: (data['sequence'] as num?)?.toInt() ?? 0,
      locationAvailability: switch (data['locationAvailability']) {
        'live' => LocationAvailability.live,
        'stale' => LocationAvailability.stale,
        _ => LocationAvailability.unavailable,
      },
      estimatedMinutes: ((data['eta'] as Map?)?['estimatedMinutes'] as num?)
          ?.toInt(),
      providerLocation: _providerLocation(data),
      customerLocation: tracking?.customerLocation,
      route: _route(data),
    );
    await applyRealtime(next);
  }

  ProviderMapLocation? _providerLocation(Map<String, Object?> data) {
    if (data['locationAvailability'] != 'live') return null;
    final location = data['location'];
    if (location is! Map) return null;
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    final accuracy = location['accuracyMeters'];
    final capturedAt = DateTime.tryParse(
      location['capturedAt']?.toString() ?? '',
    );
    final receivedAt = DateTime.tryParse(
      location['receivedAt']?.toString() ?? '',
    );
    if (latitude is! num ||
        longitude is! num ||
        accuracy is! num ||
        capturedAt == null ||
        receivedAt == null) {
      return null;
    }
    return ProviderMapLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracyMeters: accuracy.toDouble(),
      capturedAt: capturedAt,
      receivedAt: receivedAt,
    );
  }

  DrivingRoute? _route(Map<String, Object?> data) {
    final route = data['route'];
    if (route is! Map) return null;
    final distance = route['distanceMeters'];
    final duration = route['durationSeconds'];
    final rawCoordinates = route['coordinates'];
    if (distance is! num || duration is! num || rawCoordinates is! List) {
      return null;
    }
    final coordinates = rawCoordinates
        .whereType<List>()
        .where((point) =>
            point.length >= 2 && point[0] is num && point[1] is num)
        .map(
          (point) => CustomerMapLocation(
            longitude: (point[0] as num).toDouble(),
            latitude: (point[1] as num).toDouble(),
          ),
        )
        .toList();
    if (coordinates.length < 2) return null;
    return DrivingRoute(
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toInt(),
      coordinates: coordinates,
    );
  }

  Future<void> reconnect() => loadSnapshot();

  Future<void> applyRealtime(BookingTracking next) async {
    final current = tracking;
    if (next.bookingId != bookingId ||
        (current != null && next.sequence < current.sequence)) {
      return;
    }
    if (current != null && next.sequence > current.sequence + 1) {
      await loadSnapshot();
      return;
    }
    tracking = next;
    connection = TrackingConnection.live;
    message = null;
    notifyListeners();
  }

  void markDisconnected() {
    connection = TrackingConnection.offline;
    message = 'Updates paused. Last known booking status is shown.';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_projectionSubscription?.cancel());
    realtime?.dispose();
    super.dispose();
  }
}
