import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';

class ProviderFullScreenMapScreen extends StatelessWidget {
  const ProviderFullScreenMapScreen({
    required this.job,
    required this.controller,
    super.key,
  });

  final CustomerBooking job;
  final ProviderController controller;

  DrivingRoute? _generateDummyRoute(CustomerBooking job) {
    if (job.locationLatitude == null || job.locationLongitude == null) {
      return null;
    }
    return DrivingRoute(
      distanceMeters: 5000,
      durationSeconds: 600,
      coordinates: [
        CustomerMapLocation(
          latitude: job.locationLatitude! - 0.005,
          longitude: job.locationLongitude! - 0.005,
        ),
        CustomerMapLocation(
          latitude: job.locationLatitude! - 0.003,
          longitude: job.locationLongitude! - 0.005,
        ),
        CustomerMapLocation(
          latitude: job.locationLatitude! - 0.001,
          longitude: job.locationLongitude! - 0.002,
        ),
        CustomerMapLocation(
          latitude: job.locationLatitude!,
          longitude: job.locationLongitude!,
        ),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Navigation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ProviderLiveMap(
        showOverlay: true,
        route: controller.currentRoute ?? _generateDummyRoute(job),
        providerLocation: controller.currentLocation ??
            (job.locationLatitude != null && job.locationLongitude != null
                ? ProviderMapLocation(
                    latitude: job.locationLatitude! - 0.005,
                    longitude: job.locationLongitude! - 0.005,
                    accuracyMeters: 0,
                    capturedAt: DateTime.now(),
                    receivedAt: DateTime.now(),
                  )
                : null),
        customerLocation: job.locationLatitude != null &&
                job.locationLongitude != null
            ? CustomerMapLocation(
                latitude: job.locationLatitude!,
                longitude: job.locationLongitude!,
              )
            : null,
      ),
    );
  }
}
