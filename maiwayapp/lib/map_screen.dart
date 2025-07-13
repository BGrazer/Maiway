import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maiwayapp/city_boundary.dart';
import 'package:maiwayapp/search_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:maiwayapp/survey_page.dart' as my_survey;

class MapScreen extends StatefulWidget {
  final List<String> selectedPreferences;
  final List<String> selectedModes;
  final String passengerType;
  final String? cardType; // NEW

  const MapScreen({
    super.key,
    required this.selectedPreferences,
    required this.selectedModes,
    required this.passengerType,
    this.cardType,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  late final List<LatLng> _manilaBoundary;

  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _manilaBoundary = getManilaBoundary();
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _centerOnUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
      _mapController.rotate(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch location')),
      );
    }
  }

  void _resetCameraOrientation() {
    if (_currentLocation != null) {
      _mapController.rotate(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch location')),
      );
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
      builder: (context) => SearchSheet(
        originController: originController,
        destinationController: destinationController,
      ),
    );
  }

  void _openSurveyPopup() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: my_survey.SurveyPage(
        distanceKm: 5.0,
        transportMode: widget.selectedModes.isNotEmpty
            ? widget.selectedModes.first
            : 'Jeep',
        passengerType: widget.passengerType,
        selectedPreference: widget.selectedPreferences.isNotEmpty
            ? widget.selectedPreferences.first
            : 'Fastest',
      ),
    ),
  );
}


  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              const CurrentLocationLayer(),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 10),
                    Text("Where to?", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),

          // Floating Buttons
          Positioned(
            bottom: 210,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'survey_button',
              onPressed: _openSurveyPopup,
              tooltip: 'Open Survey Page',
              child: const Icon(Icons.feedback),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'reset_orientation_button',
              onPressed: _resetCameraOrientation,
              tooltip: 'Reset Orientation',
              child: const Icon(Icons.explore),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'user_location_button',
              onPressed: _centerOnUserLocation,
              tooltip: 'My Location',
              child: const Icon(Icons.my_location),
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
