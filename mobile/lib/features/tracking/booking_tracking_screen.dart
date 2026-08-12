import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:flutter/material.dart';

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
    appBar: AppBar(title: const Text('Track your booking')),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          _ConnectionCard(controller: widget.controller),
          const SizedBox(height: AppSpacing.lg),
          _TrackingCard(tracking: widget.controller.tracking),
        ],
      ),
    ),
  );
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
            style: Theme.of(context).textTheme.titleMedium,
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
      semanticLabel: 'Current booking tracking status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provider journey',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FixStatusChip(
            label: _status(value.status),
            icon: Icons.route_outlined,
            tone: FixStatusTone.info,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(locationLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value.estimatedMinutes == null
                ? 'ETA unavailable'
                : 'Estimated arrival: about ${value.estimatedMinutes} minutes',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ETA is an estimate and may change.',
            style: Theme.of(context).textTheme.bodySmall,
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
