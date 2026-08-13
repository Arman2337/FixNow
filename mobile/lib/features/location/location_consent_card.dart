import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:flutter/material.dart';

class LocationConsentCard extends StatefulWidget {
  const LocationConsentCard({required this.controller, super.key});
  final LocationConsentController controller;

  @override
  State<LocationConsentCard> createState() => _LocationConsentCardState();
}

class _LocationConsentCardState extends State<LocationConsentCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.check();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final granted = state == LocationPermissionState.granted;
      final permanent = state == LocationPermissionState.permanentlyDenied;
      return FixCard(
        semanticLabel: 'Location permission',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Use your location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              granted
                  ? 'Showing services available near you. FixNow does not store your location.'
                  : 'See what is available nearby. FixNow uses your location only while the app is open and does not store it.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (state == LocationPermissionState.checking)
              const LinearProgressIndicator(
                semanticsLabel: 'Checking location permission',
              )
            else if (granted)
              const Align(
                alignment: Alignment.centerLeft,
                child: FixStatusChip(
                  label: 'Location allowed',
                  icon: Icons.check_circle_outline,
                  tone: FixStatusTone.success,
                ),
              )
            else ...[
              if (state == LocationPermissionState.denied)
                const Text(
                  'You can still browse without sharing your location.',
                ),
              if (state == LocationPermissionState.unavailable)
                const Text(
                  'Location is unavailable. You can still browse all services.',
                ),
              const SizedBox(height: AppSpacing.md),
              FixButton(
                label: permanent ? 'Open settings' : 'Allow location',
                variant: FixButtonVariant.secondary,
                icon: permanent
                    ? Icons.settings_outlined
                    : Icons.my_location_outlined,
                onPressed: permanent
                    ? widget.controller.openSettings
                    : widget.controller.request,
              ),
            ],
          ],
        ),
      );
    },
  );
}
