import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BookingTrackingScreen extends StatefulWidget {
  const BookingTrackingScreen({required this.controller, super.key});
  final BookingTrackingController controller;
  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadSnapshot();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Track your booking'),
      actions: [
        IconButton(
          tooltip: 'Emergency SOS',
          icon: const Icon(Icons.shield_outlined, color: AppColors.emergency),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('FixNow Safety Support is standing by for active jobs.'),
              ),
            );
          },
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          _ConnectionCard(controller: widget.controller),
          const SizedBox(height: AppSpacing.md),
          _TrackingCard(tracking: widget.controller.tracking),
          const SizedBox(height: AppSpacing.lg),

          if (widget.controller.tracking?.serviceStartOtp case final otp?) ...[
            FixOtpDisplay(otp: otp),
            const SizedBox(height: AppSpacing.lg),
          ],

          FixCard(
            tone: FixCardTone.elevated,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FixTimeline(
                  currentStatus: widget.controller.tracking?.status ?? 'REQUESTED',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildQuickActionControls(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ),
  );

  Widget _buildQuickActionControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.borderStrong),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
            ),
            icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 18),
            label: const Text('Call Pro', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting to your assigned technician...')),
              );
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.borderStrong),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accentGold, size: 18),
            label: const Text('Message', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('In-app messaging for active bookings is active.')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});
  final BookingTrackingController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.connection == TrackingConnection.live) {
      return const SizedBox.shrink();
    }
    final loading = controller.connection != TrackingConnection.offline;
    return FixCard(
      semanticLabel: loading
          ? 'Refreshing booking tracking'
          : 'Tracking updates paused',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loading ? 'Refreshing updates' : 'Updates paused',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textOnLightPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loading
                ? 'Confirming the latest booking status.'
                : controller.message ?? 'Live updates are unavailable.',
          ),
          if (!loading) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Try again',
              onPressed: controller.reconnect,
              variant: FixButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.tracking});
  final BookingTracking? tracking;
  @override
  Widget build(BuildContext context) {
    final value = tracking;
    if (value == null) return const SizedBox.shrink();
    final locationLabel =
        value.locationAvailability == LocationAvailability.live
        ? 'Live location available'
        : 'Live location unavailable';
    return FixCard(
      tone: FixCardTone.elevated,
      semanticLabel: 'Current booking tracking status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Provider journey',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FixStatusChip(
                label: _status(value.status),
                icon: Icons.route_outlined,
                tone: FixStatusTone.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(locationLabel, style: Theme.of(context).textTheme.titleMedium),
          if (value.providerLocation != null) ...[
            const SizedBox(height: AppSpacing.md),
            ProviderLiveMap(
              providerLocation: value.providerLocation!,
              customerLocation: value.customerLocation,
              route: value.route,
              estimatedMinutes: value.estimatedMinutes,
              distanceKm: value.route == null
                  ? null
                  : value.route!.distanceMeters / 1000,
            ),
            if (value.route == null) ...[
              const SizedBox(height: AppSpacing.md),
              _JourneySummary(tracking: value),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.accentGold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value.estimatedMinutes == null
                      ? 'ETA unavailable'
                      : 'Estimated arrival: about ${value.estimatedMinutes} minutes',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'ETA is an estimate and may change.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _status(String value) => switch (value) {
    'EN_ROUTE' => 'Provider is on the way',
    'IN_PROGRESS' => 'Service in progress',
    'COMPLETED' => 'Service completed',
    'CANCELLED' => 'Booking cancelled',
    _ => 'Booking updated',
  };
}

class _JourneySummary extends StatelessWidget {
  const _JourneySummary({required this.tracking});

  final BookingTracking tracking;

  @override
  Widget build(BuildContext context) {
    final provider = tracking.providerLocation;
    final customer = tracking.customerLocation;
    final distanceKm = tracking.route != null
        ? tracking.route!.distanceMeters / 1000
        : provider != null && customer != null
        ? const Distance().as(
            LengthUnit.Kilometer,
            LatLng(provider.latitude, provider.longitude),
            LatLng(customer.latitude, customer.longitude),
          )
        : null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: AppRadius.buttonBorder,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              customer == null
                  ? 'Provider location is live. Your booking location is unavailable.'
                  : tracking.route == null
                  ? 'Provider → your service address'
                  : 'Driving route to your service address',
              style: const TextStyle(
                color: AppColors.textOnDarkPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (distanceKm != null)
            Text(
              '${distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                color: AppColors.textOnDarkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
