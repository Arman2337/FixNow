import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProviderLiveMap extends StatelessWidget {
  const ProviderLiveMap({required this.location, super.key});

  final ProviderMapLocation location;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(location.latitude, location.longitude);
    return Semantics(
      label: 'Live provider location map',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 240,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: position, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('assigned-provider'),
                position: position,
                infoWindow: const InfoWindow(title: 'Provider location'),
              ),
            },
            compassEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
      ),
    );
  }
}
