import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/features/location/url_launcher_stub.dart'
    if (dart.library.html) 'package:fixnow_mobile/features/location/url_launcher_web.dart';

class MapNavigationLauncher {
  static const MethodChannel _navChannel =
      MethodChannel('com.fixnow.mobile/navigation');

  /// Launches real-world driving navigation to [latitude], [longitude].
  /// On Android: uses `com.fixnow.mobile/navigation` to launch Google Maps turn-by-turn.
  /// On Web/Fallback: opens Google Maps directions in a browser window.
  static Future<void> launchNavigation({
    required BuildContext context,
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final destLabel = label ?? 'Customer Location';
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

    if (kIsWeb) {
      try {
        openUrlInNewTab(googleMapsUrl);
      } catch (e) {
        if (context.mounted) {
          showFixBanner(
            ScaffoldMessenger.of(context),
            message: 'Unable to launch maps: $e',
          );
        }
      }
      return;
    }

    try {
      final success = await _navChannel.invokeMethod<bool>('openNavigation', {
        'latitude': latitude,
        'longitude': longitude,
        'label': destLabel,
      });
      if (success == true) return;
    } on MissingPluginException {
      // Method channel not implemented on current runtime or test environment
    } catch (_) {}

    // Web/Generic browser fallback
    try {
      openUrlInNewTab(googleMapsUrl);
      if (context.mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message:
              'Opening directions to destination (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
          actionLabel: 'OK',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message:
              'Navigating to destination (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})',
          actionLabel: 'DISMISS',
        );
      }
    }
  }
}
