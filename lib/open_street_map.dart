import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const restaurantSampleLocation = LatLng(30.0561, 31.3300);

class OpenStreetMapPreview extends StatelessWidget {
  const OpenStreetMapPreview({super.key, this.height = 190});

  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          child: FlutterMap(
            options: const MapOptions(
                initialCenter: restaurantSampleLocation, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.maa.delivery.maaRestaurant',
                maxZoom: 19,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: restaurantSampleLocation,
                  width: 48,
                  height: 54,
                  child: const Icon(Icons.restaurant,
                      color: Color(0xFFFF7657), size: 36),
                ),
              ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors')
                ],
              ),
            ],
          ),
        ),
      );
}
