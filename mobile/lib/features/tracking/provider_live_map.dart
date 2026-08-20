import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ProviderLiveMap extends StatelessWidget {
  const ProviderLiveMap({
    required this.providerLocation,
    this.customerLocation,
    this.route,
    this.estimatedMinutes,
    this.distanceKm,
    super.key,
  });

  final ProviderMapLocation providerLocation;
  final CustomerMapLocation? customerLocation;
  final DrivingRoute? route;
  final int? estimatedMinutes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final provider = LatLng(
      providerLocation.latitude,
      providerLocation.longitude,
    );
    final customer = customerLocation == null
        ? null
        : LatLng(customerLocation!.latitude, customerLocation!.longitude);
    final center = customer == null
        ? provider
        : LatLng(
            (provider.latitude + customer.latitude) / 2,
            (provider.longitude + customer.longitude) / 2,
          );
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
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: customer == null ? 15.0 : 11.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fixnow.app',
                  ),
                  if (customer != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route?.coordinates
                                  .map(
                                    (point) =>
                                        LatLng(point.latitude, point.longitude),
                                  )
                                  .toList() ??
                              [provider, customer],
                          strokeWidth: route == null ? 6 : 9,
                          color: Colors.white.withValues(alpha: 0.9),
                          pattern: route == null
                              ? const StrokePattern.dotted()
                              : const StrokePattern.solid(),
                        ),
                        Polyline(
                          points: route?.coordinates
                                  .map(
                                    (point) =>
                                        LatLng(point.latitude, point.longitude),
                                  )
                                  .toList() ??
                              [provider, customer],
                          strokeWidth: route == null ? 3 : 5,
                          color: AppColors.primary,
                          pattern: route == null
                              ? const StrokePattern.dotted()
                              : const StrokePattern.solid(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: provider,
                        width: 64,
                        height: 76,
                        child: const _MapPin(
                          icon: Icons.handyman_rounded,
                          color: AppColors.primary,
                          label: 'Provider',
                          caption: 'Your FixNow pro',
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
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: IgnorePointer(
                  child: _LiveRouteBadge(estimatedMinutes: estimatedMinutes),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: IgnorePointer(
                  child: _JourneyOverlay(
                    hasCustomerLocation: customer != null,
                    estimatedMinutes: estimatedMinutes,
                    distanceKm: distanceKm,
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

class _LiveRouteBadge extends StatelessWidget {
  const _LiveRouteBadge({required this.estimatedMinutes});

  final int? estimatedMinutes;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.backgroundPrimary,
      borderRadius: AppRadius.buttonBorder,
      border: Border.all(color: AppColors.primaryHover.withValues(alpha: 0.55)),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt_rounded, color: AppColors.primaryHover, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FIXNOW LIVE',
              style: TextStyle(
                color: AppColors.primaryHover,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              estimatedMinutes == null
                  ? 'Route is active'
                  : '$estimatedMinutes min away',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
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
    this.isLive = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String caption;
  final bool isLive;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isLive ? 0.2 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(alpha: 0.9),
            borderRadius: AppRadius.pill,
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
