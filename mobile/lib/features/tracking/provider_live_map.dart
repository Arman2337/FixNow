import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The route prefix drawn up to progress [t] (0..1): whole coordinate points
/// plus one interpolated point on the segment being crossed. Pure and
/// unit-tested — the draw-on animation is just this list, replayed per tick.
@visibleForTesting
List<LatLng> sliceRoute(List<CustomerMapLocation> coordinates, double t) {
  if (coordinates.isEmpty || t <= 0) return const [];
  if (t >= 1) {
    return coordinates.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }
  final scaled = t * (coordinates.length - 1);
  final whole = scaled.floor();
  final points = <LatLng>[
    for (var i = 0; i <= whole; i += 1)
      LatLng(coordinates[i].latitude, coordinates[i].longitude),
  ];
  final frac = scaled - whole;
  if (frac > 0 && whole + 1 < coordinates.length) {
    final a = coordinates[whole];
    final b = coordinates[whole + 1];
    points.add(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * frac,
        a.longitude + (b.longitude - a.longitude) * frac,
      ),
    );
  }
  return points;
}

class ProviderLiveMap extends StatefulWidget {
  const ProviderLiveMap({
    this.providerLocation,
    this.customerLocation,
    this.route,
    this.estimatedMinutes,
    this.distanceKm,
    super.key,
  });

  final ProviderMapLocation? providerLocation;
  final CustomerMapLocation? customerLocation;
  final DrivingRoute? route;
  final int? estimatedMinutes;
  final double? distanceKm;

  @override
  State<ProviderLiveMap> createState() => _ProviderLiveMapState();
}

class _ProviderLiveMapState extends State<ProviderLiveMap>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _moveAnimController;
  late final AnimationController _routeDrawController;
  LatLng? _animatedProviderPos;
  double _currentBearing = 0.0;

  // Route draw-on state: the first time a full route arrives (null→non-null
  // with both endpoints known), the live-emerald overlay is drawn
  // progressively and the vehicle marker travels along it. Runs once.
  DrivingRoute? _drawRoute;
  List<LatLng> _sliced = const [];
  LatLng? _drawPos;
  double _drawBearing = 0.0;
  bool _routeIntroduced = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _moveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _routeDrawController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 3000),
          )
          ..addListener(_onRouteDrawTick)
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            // Hand the marker back to live GPS without a teleport: glide from
            // the route's end to wherever the provider actually is now.
            final from = _animatedProviderPos ?? _drawPos;
            final to = widget.providerLocation == null
                ? null
                : LatLng(
                    widget.providerLocation!.latitude,
                    widget.providerLocation!.longitude,
                  );
            if (mounted) {
              setState(() {
                _sliced = const [];
                _drawPos = null;
              });
            }
            if (from != null && to != null) {
              _animateProviderTo(from, to);
            }
          });
    if (widget.providerLocation != null) {
      _animatedProviderPos = LatLng(
        widget.providerLocation!.latitude,
        widget.providerLocation!.longitude,
      );
    }
    // A snapshot that already carries the route must not replay the reveal.
    if (widget.route != null) _routeIntroduced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  @override
  void didUpdateWidget(covariant ProviderLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providerLocation != oldWidget.providerLocation) {
      if (widget.providerLocation != null) {
        final newTarget = LatLng(
          widget.providerLocation!.latitude,
          widget.providerLocation!.longitude,
        );
        final currentPos = _animatedProviderPos ?? newTarget;
        _animateProviderTo(currentPos, newTarget);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    } else if (widget.customerLocation != oldWidget.customerLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
    _maybeStartRouteDraw();
  }

  /// Glides the vehicle marker from [from] to [to] over 900ms, updating
  /// bearing from the travel direction. Single home for marker movement.
  void _animateProviderTo(LatLng from, LatLng to) {
    final bearing = _calculateBearing(from, to);
    if (bearing != 0.0) {
      _currentBearing = bearing;
    }
    _moveAnimController.reset();
    final anim = CurvedAnimation(
      parent: _moveAnimController,
      curve: Curves.easeInOutCubic,
    );
    anim.addListener(() {
      if (mounted) {
        setState(() {
          _animatedProviderPos = LatLng(
            from.latitude + (to.latitude - from.latitude) * anim.value,
            from.longitude + (to.longitude - from.longitude) * anim.value,
          );
        });
      }
    });
    _moveAnimController.forward();
  }

  void _maybeStartRouteDraw() {
    if (_routeIntroduced) return;
    if (widget.route == null) return;
    if (widget.route!.coordinates.length < 2) return;
    if (widget.providerLocation == null || widget.customerLocation == null) {
      return;
    }
    // Set BEFORE starting so a rebuild mid-flight can't re-enter.
    _routeIntroduced = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return; // Static full route; nothing to animate.
    }
    _drawRoute = _orientRoute(widget.route!);
    _routeDrawController.forward(from: 0);
  }

  void _onRouteDrawTick() {
    if (!mounted || _drawRoute == null) return;
    // Route refresh mid-draw re-slices in place; never restart.
    if (!identical(widget.route, _drawRoute) && widget.route != null) {
      _drawRoute = _orientRoute(widget.route!);
    }
    final sliced = sliceRoute(
      _drawRoute!.coordinates,
      _routeDrawController.value,
    );
    if (sliced.isEmpty) return;
    final bearing = sliced.length >= 2
        ? _calculateBearing(sliced[sliced.length - 2], sliced.last)
        : _drawBearing;
    setState(() {
      _sliced = sliced;
      _drawPos = sliced.last;
      if (bearing != 0.0) _drawBearing = bearing;
    });
  }

  /// The API does not document coordinate ordering.
  /// ponytail: nearest-endpoint heuristic — if route.refresh ever gains an
  /// explicit origin flag, replace this with it.
  DrivingRoute _orientRoute(DrivingRoute route) {
    final provider = _animatedProviderPos;
    if (provider == null || route.coordinates.length < 2) return route;
    final first = route.coordinates.first;
    final last = route.coordinates.last;
    double dist(LatLng p, CustomerMapLocation q) =>
        (p.latitude - q.latitude) * (p.latitude - q.latitude) +
        (p.longitude - q.longitude) * (p.longitude - q.longitude);
    final firstIsNearer = dist(provider, first) <= dist(provider, last);
    if (firstIsNearer) return route;
    return DrivingRoute(
      coordinates: route.coordinates.reversed.toList(),
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
    );
  }

  @override
  void dispose() {
    _routeDrawController.dispose();
    _moveAnimController.dispose();
    super.dispose();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    if ((start.latitude - end.latitude).abs() < 0.00001 &&
        (start.longitude - end.longitude).abs() < 0.00001) {
      return _currentBearing;
    }
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final rad = math.atan2(y, x);
    return (rad * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _fitCamera() {
    if (!mounted) return;
    // Mid-draw the marker position is choreographed, not real GPS — don't
    // refit the viewport to it (the move-anim keeps updating the real pos).
    if (_drawPos != null) return;
    final provider =
        _animatedProviderPos ??
        (widget.providerLocation == null
            ? null
            : LatLng(
                widget.providerLocation!.latitude,
                widget.providerLocation!.longitude,
              ));
    final customer = widget.customerLocation == null
        ? null
        : LatLng(
            widget.customerLocation!.latitude,
            widget.customerLocation!.longitude,
          );

    try {
      if (provider != null && customer != null) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([provider, customer]),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
          ),
        );
      } else if (provider != null) {
        _mapController.move(provider, 14.5);
      } else if (customer != null) {
        _mapController.move(customer, 14.5);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        _animatedProviderPos ??
        (widget.providerLocation == null
            ? null
            : LatLng(
                widget.providerLocation!.latitude,
                widget.providerLocation!.longitude,
              ));
    final customer = widget.customerLocation == null
        ? null
        : LatLng(
            widget.customerLocation!.latitude,
            widget.customerLocation!.longitude,
          );
    final center = provider != null && customer != null
        ? LatLng(
            (provider.latitude + customer.latitude) / 2,
            (provider.longitude + customer.longitude) / 2,
          )
        : (provider ?? customer ?? const LatLng(23.0225, 72.5714));
    return Semantics(
      label: customer == null
          ? 'Live provider location map'
          : 'Live map showing the provider and your booking location',
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: SizedBox(
          height: 348,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: (provider != null && customer != null)
                      ? 11.5
                      : 14.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fixnow.app',
                  ),
                  if (provider != null && customer != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points:
                              widget.route?.coordinates
                                  .map(
                                    (point) =>
                                        LatLng(point.latitude, point.longitude),
                                  )
                                  .toList() ??
                              [provider, customer],
                          strokeWidth: widget.route == null ? 6 : 9,
                          color: Colors.white.withValues(alpha: 0.9),
                          pattern: widget.route == null
                              ? const StrokePattern.dotted()
                              : const StrokePattern.solid(),
                        ),
                        Polyline(
                          points:
                              widget.route?.coordinates
                                  .map(
                                    (point) =>
                                        LatLng(point.latitude, point.longitude),
                                  )
                                  .toList() ??
                              [provider, customer],
                          strokeWidth: widget.route == null ? 3 : 5,
                          color: AppColors.primary,
                          pattern: widget.route == null
                              ? const StrokePattern.dotted()
                              : const StrokePattern.solid(),
                        ),
                        // Progressive draw-on overlay (replays once on route
                        // arrival — see _maybeStartRouteDraw).
                        if (_sliced.length > 1)
                          Polyline(
                            points: _sliced,
                            strokeWidth: 5,
                            color: AppColors.live,
                            pattern: const StrokePattern.solid(),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (provider != null)
                        Marker(
                          // During the draw-on the marker rides the route
                          // head; afterwards it follows live GPS.
                          point: _drawPos ?? provider,
                          width: 72,
                          height: 84,
                          child: _VehicleMapPin(
                            bearing: _drawPos != null
                                ? _drawBearing
                                : _currentBearing,
                            isLive: true,
                          ),
                        ),
                      if (customer != null)
                        Marker(
                          point: customer,
                          width: 64,
                          height: 76,
                          child: const _MapPin(
                            icon: Icons.home_rounded,
                            color: AppColors.success,
                            label: 'You',
                            caption: 'Service address',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.45, 1],
                        colors: [
                          Color(0x52081020),
                          Colors.transparent,
                          Color(0x8F081020),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Top Floating Glassmorphic Telemetry Card
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: 98,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE60F172A),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: provider != null
                          ? AppColors.live.withValues(alpha: 0.6)
                          : AppColors.borderStrong,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider != null
                            ? Icons.two_wheeler_rounded
                            : Icons.radar_rounded,
                        color: provider != null
                            ? AppColors.live
                            : AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider != null && widget.estimatedMinutes != null
                              ? 'Technician en route • ${widget.distanceKm != null ? "${widget.distanceKm!.toStringAsFixed(1)} km • " : ""}~${widget.estimatedMinutes} mins'
                              : 'Connecting to technician GPS...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: Material(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: _fitCamera,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fit View',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: IgnorePointer(
                  child: _JourneyOverlay(
                    hasCustomerLocation: customer != null,
                    estimatedMinutes: widget.estimatedMinutes,
                    distanceKm: widget.distanceKm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyOverlay extends StatelessWidget {
  const _JourneyOverlay({
    required this.hasCustomerLocation,
    required this.estimatedMinutes,
    required this.distanceKm,
  });

  final bool hasCustomerLocation;
  final int? estimatedMinutes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.backgroundPrimary.withValues(alpha: 0.94),
      borderRadius: AppRadius.cardBorder,
      border: Border.all(color: Colors.white24),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.handyman_rounded,
            color: AppColors.onPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasCustomerLocation
                    ? 'Provider is on the way'
                    : 'Provider location is live',
                style: const TextStyle(
                  color: AppColors.textOnDarkPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Verified FixNow service journey',
                style: TextStyle(
                  color: AppColors.textOnDarkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: AppRadius.buttonBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayMetric(
                icon: Icons.timer_outlined,
                value: estimatedMinutes == null ? '—' : '${estimatedMinutes}m',
                label: 'ETA',
              ),
              Container(
                height: 28,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: Colors.white24,
              ),
              _OverlayMetric(
                icon: Icons.route_outlined,
                value: distanceKm == null
                    ? '—'
                    : '${distanceKm!.toStringAsFixed(1)} km',
                label: 'route',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OverlayMetric extends StatelessWidget {
  const _OverlayMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textOnDarkPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 11),
      ),
    ],
  );
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 8),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textOnDarkPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VehicleMapPin extends StatelessWidget {
  const _VehicleMapPin({required this.bearing, this.isLive = true});

  final double bearing;
  final bool isLive;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Technician live location',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isLive) ...[
              // Trailing telemetry comet glow behind the vehicle heading
              Transform.translate(
                offset: Offset(
                  math.cos((bearing + 90) * (math.pi / 180.0)) * 14.0,
                  math.sin((bearing + 90) * (math.pi / 180.0)) * 14.0,
                ),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.live.withValues(alpha: 0.35),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.live.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
            ],
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: bearing * (math.pi / 180.0),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.two_wheeler_rounded,
                  color: AppColors.primary,
                  size: 10,
                ),
                SizedBox(width: 3),
                Text(
                  'Technician',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
