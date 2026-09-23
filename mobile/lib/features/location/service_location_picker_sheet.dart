import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Modal bottom sheet allowing the customer to pin their exact service location on the map.
class ServiceLocationPickerSheet extends StatefulWidget {
  const ServiceLocationPickerSheet({this.initialLocation, super.key});

  final BookingLocationFix? initialLocation;

  static Future<BookingLocationFix?> show(
    BuildContext context, {
    BookingLocationFix? initialLocation,
  }) => showModalBottomSheet<BookingLocationFix>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ServiceLocationPickerSheet(initialLocation: initialLocation),
  );

  @override
  State<ServiceLocationPickerSheet> createState() =>
      _ServiceLocationPickerSheetState();
}

class _ServiceLocationPickerSheetState
    extends State<ServiceLocationPickerSheet> {
  static const _worldView = LatLng(20.5937, 78.9629);

  late LatLng _selected = widget.initialLocation == null
      ? _worldView
      : LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );

  /// True only once the pin reflects a deliberate choice — an arriving GPS
  /// fix or a map tap. Never pre-armed by the world-view default, so the
  /// confirm button cannot return coordinates the customer never picked.
  late bool _pinPlaced = widget.initialLocation != null;
  BookingLocationProvider? _resolver;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _resolver = BookingLocationResolver(initialFix: widget.initialLocation);
    _locate();
  }

  /// One real GPS attempt when the sheet opens without a location. The
  /// resolver asks for permission; on any failure the world view stays and
  /// the customer places the pin manually.
  Future<void> _locate() async {
    try {
      final fix = await (_resolver ?? BookingLocationResolver()).resolve();
      if (!mounted) return;
      setState(() {
        _selected = LatLng(fix.latitude, fix.longitude);
        _pinPlaced = true;
      });
      // initialCenter only applies at construction — glide the viewport to
      // the real fix explicitly.
      try {
        _mapController.move(_selected, 15);
      } catch (_) {
        // Map not mounted yet; initialCenter already carries the fix.
      }
    } on BookingLocationFailure {
      // World view + manual pin; the confirm button stays disabled.
    } catch (_) {
      // Same honest fallback for unexpected locator errors.
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirm service location',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Tap your home or service address on the map. This pin matches nearby service providers.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label:
                  'Service location map. Tap to place the service address pin.',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 320,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selected,
                      initialZoom: _pinPlaced ? 15 : 5,
                      onTap: (_, point) => setState(() {
                        _selected = point;
                        _pinPlaced = true;
                      }),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.fixnow.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selected,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FixPrimaryButton(
              label: _pinPlaced
                  ? 'Use this service location'
                  : 'Tap the map to place your pin',
              icon: Icons.check_rounded,
              onPressed: !_pinPlaced
                  ? null
                  : () => Navigator.of(context).pop(
                      BookingLocationFix(
                        latitude: _selected.latitude,
                        longitude: _selected.longitude,
                        accuracyMeters: 0,
                        timestamp: DateTime.now(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
