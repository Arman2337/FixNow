import 'dart:async';

import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/road_routing_service.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

class BookingTrackingController extends ChangeNotifier {
  BookingTrackingController({
    required this.bookingId,
    required this.source,
    this.realtime,
    RoadRoutingService? routingService,
    CustomerBooking? initialBooking,
  }) : routingService = routingService ?? RoadRoutingService.instance,
       tracking = initialBooking != null
           ? BookingTracking.fromBooking(initialBooking)
           : null;
  final String bookingId;
  final BookingTrackingSource source;
  final RealtimeClient? realtime;
  final RoadRoutingService routingService;
  StreamSubscription<RealtimeProjection>? _projectionSubscription;
  Timer? _stalenessTimer;
  bool _otpFetchInFlight = false;
  bool _fetchingRoute = false;
  TrackingConnection connection = TrackingConnection.connecting;
  BookingTracking? tracking;
  String? message;

  void seedBooking(CustomerBooking booking) {
    if (booking.id.trim().toLowerCase() != bookingId.trim().toLowerCase()) return;
    if (tracking == null) {
      tracking = BookingTracking.fromBooking(booking);
      notifyListeners();
    } else {
      final current = tracking!;
      final shouldUpdate =
          (current.providerName == null && booking.providerName != null) ||
          (current.providerRating == null && booking.providerRating != null) ||
          (current.providerJobsCount == null && booking.providerJobsCount != null) ||
          (current.providerPhone == null && booking.providerPhone != null) ||
          (current.customerLocation == null &&
              booking.locationLatitude != null &&
              booking.locationLongitude != null);
      if (shouldUpdate) {
        tracking = current.copyWith(
          providerName: current.providerName ?? booking.providerName,
          providerRating: current.providerRating ?? booking.providerRating,
          providerJobsCount:
              current.providerJobsCount ?? booking.providerJobsCount,
          providerPhone: current.providerPhone ?? booking.providerPhone,
          customerLocation: current.customerLocation ??
              (booking.locationLatitude != null && booking.locationLongitude != null
                  ? CustomerMapLocation(
                      latitude: booking.locationLatitude!,
                      longitude: booking.locationLongitude!,
                    )
                  : null),
        );
        notifyListeners();
        if (tracking?.providerLocation != null &&
            tracking?.customerLocation != null &&
            tracking?.route == null) {
          _resolveRoadRoute();
        }
      }
    }
  }

  Future<void> loadSnapshot() async {
    connection = TrackingConnection.reconciling;
    notifyListeners();
    try {
      final snapshot = await source.fetchSnapshot(bookingId);
      final current = tracking;
      if (current != null) {
        tracking = snapshot.copyWith(
          locationAvailability: snapshot.providerLocation != null
              ? snapshot.locationAvailability
              : (current.providerLocation != null
                  ? current.locationAvailability
                  : snapshot.locationAvailability),
          estimatedMinutes:
              current.estimatedMinutes ?? snapshot.estimatedMinutes,
          providerLocation:
              snapshot.providerLocation ?? current.providerLocation,
          customerLocation:
              snapshot.customerLocation ?? current.customerLocation,
          route: current.route ?? snapshot.route,
          serviceStartOtp: snapshot.serviceStartOtp ?? current.serviceStartOtp,
          providerName: snapshot.providerName ?? current.providerName,
          providerRating: snapshot.providerRating ?? current.providerRating,
          providerJobsCount:
              snapshot.providerJobsCount ?? current.providerJobsCount,
          providerPhone: snapshot.providerPhone ?? current.providerPhone,
          items: snapshot.items.isNotEmpty ? snapshot.items : current.items,
          pricing: snapshot.pricing ?? current.pricing,
        );
      } else {
        tracking = snapshot;
      }
      _projectionSubscription ??= realtime?.projections.listen(
        _applyProjection,
      );
      try {
        await realtime?.subscribeBooking(bookingId);
        connection = TrackingConnection.live;
        message = null;
      } catch (_) {
        if (realtime?.isConnected ?? false) {
          connection = TrackingConnection.live;
          message = null;
        } else {
          connection = TrackingConnection.connecting;
        }
      }
      if (tracking?.status == 'EN_ROUTE') {
        _stalenessTimer ??= Timer.periodic(
          const Duration(seconds: 15),
          (_) => evaluateStaleness(),
        );
      } else {
        _stalenessTimer?.cancel();
        _stalenessTimer = null;
      }
      if (tracking?.providerLocation != null &&
          tracking?.customerLocation != null &&
          tracking?.route == null) {
        _resolveRoadRoute();
      }
    } catch (_) {
      connection = TrackingConnection.offline;
      message = 'Tracking is temporarily unavailable.';
    }
    notifyListeners();
  }

  Future<void> _applyProjection(RealtimeProjection projection) async {
    final data = projection.data;
    final parsedLoc = _providerLocation(data);
    final preservedLoc =
        parsedLoc ??
        ((data['status'] == 'EN_ROUTE' || tracking?.status == 'EN_ROUTE')
            ? tracking?.providerLocation
            : null);
    final parsedRoute = _route(data);
    final preservedRoute =
        parsedRoute ??
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
        _ =>
          preservedLoc != null
              ? (tracking?.locationAvailability ?? LocationAvailability.live)
              : LocationAvailability.unavailable,
      },
      estimatedMinutes:
          ((data['eta'] as Map?)?['estimatedMinutes'] as num?)?.toInt() ??
          tracking?.estimatedMinutes,
      providerLocation: preservedLoc,
      customerLocation: tracking?.customerLocation,
      route: preservedRoute,
      serviceStartOtp: data['status'] == 'EN_ROUTE'
          ? tracking?.serviceStartOtp
          : null,
      // If the projection carries provider identity, use it; otherwise preserve
      // the snapshot's rather than blanking the specialist card.
      providerName:
          data['providerName']?.toString() ?? tracking?.providerName,
      providerRating:
          (data['providerRating'] as num?)?.toDouble() ??
          tracking?.providerRating,
      providerJobsCount:
          (data['providerJobsCount'] as num?)?.toInt() ??
          tracking?.providerJobsCount,
      providerPhone:
          data['providerPhone']?.toString() ?? tracking?.providerPhone,
      // A provider's on-site price adjustment arrives on this same frame.
      // Rendering the snapshot's totals until the next load would show the
      // customer a stale amount while the technician watches it change.
      items: _items(data) ?? tracking?.items ?? const [],
      pricing: _pricing(data) ?? tracking?.pricing,
    );
    await applyRealtime(next);
  }

  List<BookingLineItem>? _items(Map<String, Object?> data) {
    final raw = data['items'];
    if (raw is! List || raw.isEmpty) return null;
    try {
      return raw
          .map(
            (item) => BookingLineItem.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return null;
    }
  }

  BookingPricing? _pricing(Map<String, Object?> data) {
    final raw = data['pricing'];
    if (raw is! Map || raw.isEmpty) return null;
    try {
      return BookingPricing.fromJson(Map<String, Object?>.from(raw));
    } on FormatException {
      return null;
    }
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
        tracking = latest.copyWith(serviceStartOtp: otp);
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
    if (next.status == 'EN_ROUTE') {
      _stalenessTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => evaluateStaleness(),
      );
    } else {
      _stalenessTimer?.cancel();
      _stalenessTimer = null;
    }
    notifyListeners();
    if (next.providerLocation != null &&
        next.customerLocation != null &&
        next.route == null) {
      _resolveRoadRoute();
    }
  }

  /// Updates the tracking route (and calculated ETA if not yet set) when resolved.
  void updateRoute(DrivingRoute route) {
    final current = tracking;
    if (current == null) return;
    if (current.route != null &&
        current.route!.coordinates.length == route.coordinates.length) {
      return;
    }
    final calcEta = (route.durationSeconds / 60).ceil().clamp(1, 180);
    tracking = current.copyWith(
      route: route,
      estimatedMinutes: current.estimatedMinutes ?? calcEta,
    );
    notifyListeners();
  }

  Future<void> _resolveRoadRoute() async {
    if (_fetchingRoute) return;
    final current = tracking;
    if (current == null) return;
    final provider = current.providerLocation;
    final customer = current.customerLocation;
    if (provider == null || customer == null) return;
    if (current.route != null && current.route!.coordinates.length >= 2) return;

    _fetchingRoute = true;
    try {
      final route = await routingService.getRoadRoute(
        originLat: provider.latitude,
        originLng: provider.longitude,
        destLat: customer.latitude,
        destLng: customer.longitude,
      );
      final latest = tracking;
      if (route != null && latest != null) {
        final calcEta = (route.durationSeconds / 60).ceil().clamp(1, 180);
        tracking = latest.copyWith(
          route: route,
          estimatedMinutes: latest.estimatedMinutes ?? calcEta,
        );
        notifyListeners();
      }
    } catch (_) {
      // Graceful degradation: preserves current state
    } finally {
      _fetchingRoute = false;
    }
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
    tracking = current.copyWith(
      locationAvailability: LocationAvailability.stale,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_projectionSubscription?.cancel());
    _stalenessTimer?.cancel();
    super.dispose();
  }
}
