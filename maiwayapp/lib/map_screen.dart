import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:maiwayapp/city_boundary.dart';
import 'package:maiwayapp/search_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  double _heading = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;

  late final List<LatLng> _manilaBoundary;
  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _manilaBoundary = getManilaBoundary();

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() {
          _heading = event.heading!;
        });
      }
    });
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _centerOnUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
      _mapController.rotate(0);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to fetch location')));
    }
  }

  void _resetCameraOrientation() {
    if (_currentLocation != null) {
      _mapController.rotate(0);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to fetch location')));
    }
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder:
          (context) => SearchSheet(
            originController: originController,
            destinationController: destinationController,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.notoSerifDevanagari(
              fontSize: 22,
              color: Colors.black,
            ),
            children: const [
              TextSpan(text: 'M'),
              TextSpan(text: 'AI', style: TextStyle(fontSize: 27)),
              TextSpan(text: 'WAY'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(14.5995, 120.9842),
              initialZoom: 13.5,
              interactionOptions: const InteractionOptions(
                flags: ~InteractiveFlag.doubleTapDragZoom,
              ),
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  LatLng(14.66, 120.92),
                  LatLng(14.54, 121.05),
                ),
              ),
            ),
            children: [
              openStreetMapTileLayer,
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _manilaBoundary,
                    color: Colors.transparent,
                    borderColor: Colors.redAccent,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Transform.rotate(
                        angle:
                            _heading * (3.1415927 / 180), // degrees to radians
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer transparent blue circle
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ),
                            // Inner solid blue dot
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ),
                            // Directional arrow
                            const Positioned(
                              top: 6,
                              child: Icon(
                                Icons.arrow_drop_up,
                                size: 24,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Search Bar
          Positioned(
            top: 7,
            left: 7,
            right: 7,
            child: GestureDetector(
              onTap: _openSearchSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 10),
                    Text("Where to?", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),

          // Location button
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              elevation: 4,
              onPressed: _centerOnUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Orientation reset button
          Positioned(
            bottom: 150,
            right: 20,
            child: FloatingActionButton(
              elevation: 4,
              onPressed: _resetCameraOrientation,
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }

  TileLayer get openStreetMapTileLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.maiway',
  );
}
