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
  Timer? _stalenessTimer;
  bool _otpFetchInFlight = false;
  TrackingConnection connection = TrackingConnection.connecting;
  BookingTracking? tracking;
  String? message;

  Future<void> loadSnapshot() async {
    connection = TrackingConnection.reconciling;
    notifyListeners();
    try {
      final snapshot = await source.fetchSnapshot(bookingId);
      final current = tracking;
      if (current != null && current.providerLocation != null) {
        tracking = BookingTracking(
          bookingId: snapshot.bookingId,
          status: snapshot.status,
          sequence: snapshot.sequence,
          locationAvailability: snapshot.providerLocation != null
              ? snapshot.locationAvailability
              : current.locationAvailability,
          estimatedMinutes: current.estimatedMinutes ?? snapshot.estimatedMinutes,
          providerLocation: snapshot.providerLocation ?? current.providerLocation,
          customerLocation: snapshot.customerLocation ?? current.customerLocation,
          route: current.route ?? snapshot.route,
          serviceStartOtp: snapshot.serviceStartOtp ?? current.serviceStartOtp,
        );
      } else {
        tracking = snapshot;
      }
      _projectionSubscription ??= realtime?.projections.listen(
        _applyProjection,
      );
      await realtime?.subscribeBooking(bookingId);
      connection = TrackingConnection.live;
      message = null;
      _stalenessTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => evaluateStaleness(),
      );
    } catch (_) {
      connection = TrackingConnection.offline;
      message = 'Tracking is temporarily unavailable.';
    }
    notifyListeners();
  }

  Future<void> _applyProjection(RealtimeProjection projection) async {
    final data = projection.data;
    final parsedLoc = _providerLocation(data);
    final preservedLoc = parsedLoc ??
        ((data['status'] == 'EN_ROUTE' || tracking?.status == 'EN_ROUTE')
            ? tracking?.providerLocation
            : null);
    final parsedRoute = _route(data);
    final preservedRoute = parsedRoute ??
        ((data['status'] == 'EN_ROUTE' || tracking?.status == 'EN_ROUTE')
            ? tracking?.route
            : null);
    final next = BookingTracking(
      bookingId: data['bookingId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      sequence: (data['sequence'] as num?)?.toInt() ?? 0,
      locationAvailability: switch (data['locationAvailability']) {
        'live' => LocationAvailability.live,
        'stale' => LocationAvailability.stale,
        _ => preservedLoc != null
            ? (tracking?.locationAvailability ?? LocationAvailability.live)
            : LocationAvailability.unavailable,
      },
      estimatedMinutes: ((data['eta'] as Map?)?['estimatedMinutes'] as num?)
              ?.toInt() ??
          tracking?.estimatedMinutes,
      providerLocation: preservedLoc,
      customerLocation: tracking?.customerLocation,
      route: preservedRoute,
      serviceStartOtp: data['status'] == 'EN_ROUTE'
          ? tracking?.serviceStartOtp
          : null,
    );
    await applyRealtime(next);
  }

  ProviderMapLocation? _providerLocation(Map<String, Object?> data) {
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
        .where(
          (point) => point.length >= 2 && point[0] is num && point[1] is num,
        )
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
    if (next.bookingId.trim().toLowerCase() != bookingId.trim().toLowerCase() ||
        (current != null && next.sequence < current.sequence)) {
      return;
    }
    if (current != null && next.sequence > current.sequence + 1) {
      await loadSnapshot();
      final reconciled = tracking;
      // The HTTP booking snapshot deliberately does not include provider
      // location, route, or ETA. Keep a newer websocket projection after the
      // snapshot so a sequence gap cannot erase an already received journey.
      if (reconciled == null || next.sequence >= reconciled.sequence) {
        _applyTracking(next);
      }
    } else {
      _applyTracking(next);
    }
    await _ensureServiceStartOtp(next);
  }

  /// The OTP only exists once the provider is en route, which usually happens
  /// while the customer is already watching this screen — the snapshot taken
  /// earlier has none. Fetch it on the en-route transition.
  Future<void> _ensureServiceStartOtp(BookingTracking next) async {
    if (next.status != 'EN_ROUTE' || _otpFetchInFlight) return;
    final current = tracking;
    if (current == null || current.serviceStartOtp != null) return;
    _otpFetchInFlight = true;
    try {
      final otp = await source.fetchServiceStartOtp(bookingId);
      final latest = tracking;
      if (otp != null &&
          latest != null &&
          latest.status == 'EN_ROUTE' &&
          latest.serviceStartOtp == null) {
        tracking = BookingTracking(
          bookingId: latest.bookingId,
          status: latest.status,
          sequence: latest.sequence,
          locationAvailability: latest.locationAvailability,
          estimatedMinutes: latest.estimatedMinutes,
          providerLocation: latest.providerLocation,
          customerLocation: latest.customerLocation,
          route: latest.route,
          serviceStartOtp: otp,
        );
        notifyListeners();
      }
    } catch (_) {
      // The backend rejects the request until the en-route transition is
      // committed; the next projection retries.
    } finally {
      _otpFetchInFlight = false;
    }
  }

  void _applyTracking(BookingTracking next) {
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

  /// A "live" pin older than the backend's location cache TTL is no longer
  /// real time — the provider stopped sending (app backgrounded, poor GPS).
  /// Keep the last pin and route on screen but stop calling them live; the
  /// next projection restores availability.
  void evaluateStaleness() {
    final current = tracking;
    final receivedAt = current?.providerLocation?.receivedAt;
    if (current == null ||
        receivedAt == null ||
        current.status != 'EN_ROUTE' ||
        current.locationAvailability != LocationAvailability.live ||
        DateTime.now().difference(receivedAt) <= const Duration(seconds: 60)) {
      return;
    }
    tracking = BookingTracking(
      bookingId: current.bookingId,
      status: current.status,
      sequence: current.sequence,
      locationAvailability: LocationAvailability.stale,
      estimatedMinutes: current.estimatedMinutes,
      providerLocation: current.providerLocation,
      customerLocation: current.customerLocation,
      route: current.route,
      serviceStartOtp: current.serviceStartOtp,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_projectionSubscription?.cancel());
    _stalenessTimer?.cancel();
    realtime?.dispose();
    super.dispose();
  }
}
