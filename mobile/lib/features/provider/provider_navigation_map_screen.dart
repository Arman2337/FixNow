import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_otp_input_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/call/call_screen.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/location/map_navigation_launcher.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';

/// Full-screen navigation map screen for service technicians.
/// Displays the live interactive route from the provider to the customer's
/// exact service location, complete with distance, estimated travel time,
/// contact options, and one-tap turn-by-turn navigation via external Google Maps.
class ProviderNavigationMapScreen extends StatefulWidget {
  const ProviderNavigationMapScreen({
    required this.job,
    required this.controller,
    this.chatRepository,
    this.callRepository,
    super.key,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final ChatRepository? chatRepository;
  final CallRepository? callRepository;

  @override
  State<ProviderNavigationMapScreen> createState() =>
      _ProviderNavigationMapScreenState();
}

class _ProviderNavigationMapScreenState
    extends State<ProviderNavigationMapScreen> {
  DrivingRoute? _directRoute;
  bool _fetchingRoute = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _fetchRoadRouteIfNeeded();
  }

  void _onControllerChanged() {
    if (widget.controller.currentRoute == null && _directRoute == null) {
      _fetchRoadRouteIfNeeded();
    }
  }

  @override
  void didUpdateWidget(ProviderNavigationMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (widget.controller.currentRoute == null && _directRoute == null) {
      _fetchRoadRouteIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _fetchRoadRouteIfNeeded() async {
    if (widget.controller.currentRoute != null) return;
    if (_fetchingRoute) return;
    final provider = _providerPos(widget.controller);
    final custLat = widget.job.locationLatitude;
    final custLng = widget.job.locationLongitude;
    if (provider == null || custLat == null || custLng == null) return;

    _fetchingRoute = true;

    // 1. Try OpenRouteService
    try {
      const orsKey =
          'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQzOWUxYTg5ZWQ1ZTRmZTVhYzA2NjQ5ZmY1YzdjZDdhIiwiaCI6Im11cm11cjY0In0=';
      final orsUrl = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
      );
      final orsRes = await http
          .post(
            orsUrl,
            headers: {
              'Authorization': orsKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [provider.longitude, provider.latitude],
                [custLng, custLat],
              ],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (orsRes.statusCode == 200) {
        final data = jsonDecode(orsRes.body);
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
            final route = DrivingRoute(
              distanceMeters: (summary?['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (summary?['duration'] as num?)?.toInt() ?? 0,
              coordinates: points,
            );
            if (mounted) {
              setState(() => _directRoute = route);
              widget.controller.currentRoute = route;
            }
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Resilient fallback: Open Source Routing Machine (OSRM)
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${provider.longitude},${provider.latitude};$custLng,$custLat?overview=full&geometries=geojson',
      );
      final osrmRes = await http
          .get(osrmUrl, headers: {'User-Agent': 'FixNow-Mobile/1.0'})
          .timeout(const Duration(seconds: 5));
      if (osrmRes.statusCode == 200) {
        final data = jsonDecode(osrmRes.body);
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
            final route = DrivingRoute(
              distanceMeters: distance,
              durationSeconds: duration,
              coordinates: points,
            );
            if (mounted) {
              setState(() => _directRoute = route);
              widget.controller.currentRoute = route;
            }
          }
        }
      }
    } catch (_) {
    } finally {
      _fetchingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final custLat = widget.job.locationLatitude;
    final custLng = widget.job.locationLongitude;
    final hasDestination = custLat != null && custLng != null;
    final customerPos = !hasDestination
        ? null
        : CustomerMapLocation(latitude: custLat, longitude: custLng);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        // Live GPS and the road route arrive over the socket while this screen
        // is open; without listening the distance and pin froze on whatever
        // happened to be cached at push time.
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Stack(
            children: [
              // 1. Full-Screen Interactive Live Map
              Positioned.fill(
                child: ProviderLiveMap(
                  providerLocation: _providerPos(widget.controller),
                  customerLocation: customerPos,
                  route: _route(widget.controller),
                  distanceKm: _distanceKm(widget.controller, customerPos),
                  estimatedMinutes:
                      _estimatedMinutes(widget.controller, customerPos),
                  showOverlay: false,
                  isProviderPerspective: true,
                ),
              ),

              // 2. Top Header with Back, Title, and Direct Maps Launcher
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary.withValues(alpha: 0.92),
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.cream,
                        ),
                        tooltip: 'Back to job',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Route to Customer',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cream,
                              ),
                            ),
                            Text(
                              'Job #${_shortId(widget.job.id)} · ${widget.job.serviceCategoryId.replaceAll('_', ' ').toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.near_me_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Open in Google Maps',
                        onPressed: hasDestination
                            ? () => _launchExternalNavigation(
                                context,
                                custLat,
                                custLng,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Floating Route Metrics Pill
              Positioned(
                top: 76,
                left: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_distanceKm(widget.controller, customerPos).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.accentGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '~${_estimatedMinutes(widget.controller, customerPos)} min',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cream,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Cockpit Control Card
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary.withValues(alpha: 0.95),
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Destination Address Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emergency.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.emergency,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasDestination
                                      ? 'Customer Service Location (${custLat.toStringAsFixed(4)}, ${custLng.toStringAsFixed(4)})'
                                      : 'Customer Service Address on file',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cream,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FixStatusChip(
                            label: widget.job.status.replaceAll('_', ' '),
                            icon: Icons.navigation_rounded,
                            tone: widget.job.status == 'EN_ROUTE'
                                ? FixStatusTone.live
                                : FixStatusTone.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Primary Button: Open Google Maps Navigation
                      FixButton(
                        label: 'Start Turn-by-Turn in Google Maps',
                        icon: Icons.navigation_rounded,
                        trailingIcon: Icons.open_in_new_rounded,
                        onPressed: hasDestination
                            ? () => _launchExternalNavigation(
                                context,
                                custLat,
                                custLng,
                              )
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Secondary Action Buttons Row
                      Row(
                        children: [
                          if (widget.job.status == 'EN_ROUTE')
                            Expanded(
                              child: FixButton(
                                label: 'Verify OTP',
                                icon: Icons.lock_open_rounded,
                                variant: FixButtonVariant.secondary,
                                onPressed: () async {
                                  final otp = await FixOtpInputSheet.show(
                                    context,
                                  );
                                  if (otp != null && context.mounted) {
                                    await widget.controller.verifyOtpAndStartJob(
                                      widget.job,
                                      otp,
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                },
                              ),
                            ),
                          if (widget.job.status == 'EN_ROUTE')
                            const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FixButton(
                              label: 'Chat',
                              icon: Icons.chat_bubble_outline_rounded,
                              variant: FixButtonVariant.tertiary,
                              onPressed: () => _openChat(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FixButton(
                              label: 'Call',
                              icon: Icons.phone_rounded,
                              variant: FixButtonVariant.tertiary,
                              onPressed: () => _openCall(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Live GPS first: the registered base pin can sit kilometres away from where
  /// the technician actually is, which is what made this screen report a trip
  /// far longer than the real one.
  ProviderMapLocation? _providerPos(ProviderController controller) {
    final live = controller.currentLocation;
    final latitude = live?.latitude ?? controller.profile?.baseLatitude;
    final longitude = live?.longitude ?? controller.profile?.baseLongitude;
    if (latitude == null || longitude == null) return null;
    return ProviderMapLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: live?.accuracyMeters ?? 5.0,
      capturedAt: live?.capturedAt ?? DateTime.now(),
      receivedAt: live?.receivedAt ?? DateTime.now(),
    );
  }

  /// The backend road route when it exists, otherwise the directly fetched route.
  DrivingRoute? _route(ProviderController controller) {
    final route = controller.currentRoute ?? _directRoute;
    return (route?.coordinates.length ?? 0) >= 2 ? route : null;
  }

  double _straightLineKm(
    ProviderController controller,
    CustomerMapLocation? customer,
  ) {
    final provider = _providerPos(controller);
    if (provider == null || customer == null) return 0;
    return _haversineDistanceKm(
      provider.latitude,
      provider.longitude,
      customer.latitude,
      customer.longitude,
    );
  }

  double _distanceKm(
    ProviderController controller,
    CustomerMapLocation? customer,
  ) {
    final route = _route(controller);
    return route != null
        ? route.distanceMeters / 1000
        : _straightLineKm(controller, customer);
  }

  int _estimatedMinutes(
    ProviderController controller,
    CustomerMapLocation? customer,
  ) {
    final route = _route(controller);
    if (route != null) {
      return math.max(1, (route.durationSeconds / 60).round());
    }
    return math.max(
      2,
      (_straightLineKm(controller, customer) / 30.0 * 60).round(),
    );
  }

  void _launchExternalNavigation(BuildContext context, double lat, double lng) {
    MapNavigationLauncher.launchNavigation(
      context: context,
      latitude: lat,
      longitude: lng,
      label: 'Customer Location #${_shortId(widget.job.id)}',
    );
  }

  void _openChat(BuildContext context) {
    if (widget.chatRepository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingChatScreen(
          controller: ChatController(
            repository: widget.chatRepository!,
            bookingId: widget.job.id,
            realtimeClient: widget.controller.realtime,
            isProvider: true,
          ),
          providerName: 'Customer',
        ),
      ),
    );
  }

  void _openCall(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CallScreen(
        oppositePartyName: 'Customer',
        oppositePartyRole: 'Customer',
        phoneNumber: widget.job.customerPhone,
        bookingId: widget.job.id,
        isProvider: true,
      ),
    ));
  }

  static double _haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static String _shortId(String id) {
    final clean = id.replaceAll('-', '');
    return clean.length > 8
        ? clean.substring(0, 8).toUpperCase()
        : clean.toUpperCase();
  }
}
