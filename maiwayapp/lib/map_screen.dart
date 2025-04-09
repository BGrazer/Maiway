import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaiWay', style: TextStyle(fontSize: 22)),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(14.5995, 120.9842), // Manila coordinates
          initialZoom: 13.5,
          interactionOptions: const InteractionOptions(
            flags: ~InteractiveFlag.doubleTapDragZoom,
          ),
          cameraConstraint: CameraConstraint.contain(
            bounds: LatLngBounds(LatLng(14.45, 120.90), LatLng(14.75, 121.10)),
          ),
        ),
        children: [openStreetMapTileLayer],
      ),
    );
  }

  TileLayer get openStreetMapTileLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.maiway',
  );
}
