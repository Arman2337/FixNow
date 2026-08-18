import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
          child: FlutterMap(
            options: MapOptions(
              initialCenter: position,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fixnow.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: position,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.blueAccent,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
