import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maiwayapp/city_boundary.dart';
import 'package:maiwayapp/search_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:maiwayapp/chatbot_dialog.dart';
import 'package:maiwayapp/survey_page.dart' as my_survey;
import 'package:maiwayapp/controllers/map_screen_controller.dart';
import 'package:maiwayapp/services/geocoding_service.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapScreen extends StatefulWidget {
  final List<String> selectedPreferences;
  final List<String> selectedModes;
  final String passengerType;
  final String? cardType;

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
  late MapScreenController _controller;
  late final List<LatLng> _manilaBoundary;
  bool _isPinningMode = false;
  bool _isPinningOrigin = true;

  // Confirm the pin positioned at the map center and return to SearchSheet
  Future<void> _confirmPinAndReturnToSearch() async {
    final pinnedLocation = _controller.mapController.camera.center;

    String address;
    try {
      address = await GeocodingService.getAddressFromLocation(pinnedLocation);
    } catch (_) {
      address =
          'Lat: ${pinnedLocation.latitude.toStringAsFixed(4)}, Lng: ${pinnedLocation.longitude.toStringAsFixed(4)}';
    }

    await _addLocationMarker(pinnedLocation, address, _isPinningOrigin);

    if (mounted) {
      setState(() {
        _isPinningMode = false;
      });
    }

    // Re-open the search sheet so the user sees the updated pins
    _openSearchSheet();
  }

  @override
  void initState() {
    super.initState();
    _controller = MapScreenController(
      showError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      },
      showSuccess: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
        }
      },
      setState: () => setState(() {}),
    );
    _controller.getCurrentLocation();
    _manilaBoundary = getManilaBoundary();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerOnUserLocation() {
    if (_controller.currentLocation != null) {
      _controller.mapController.move(_controller.currentLocation!, 15.0);
      _controller.mapController.rotate(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch location')),
      );
    }
  }

  void _resetCameraOrientation() {
    _controller.mapController.rotate(0);
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
        onLocationSelected: (LatLng location, String address, bool isOrigin) async {
          await _addLocationMarker(location, address, isOrigin);
        },
        onPinModeRequested: (bool isOrigin) {
          if (mounted) {
            setState(() {
              _isPinningMode = true;
              _isPinningOrigin = isOrigin;
            });
          }
          Navigator.pop(context);
        },
        currentLocation: _controller.currentLocation ?? LatLng(14.5995, 120.9842),
        originAddress: _controller.originController.text,
        destinationAddress: _controller.destinationController.text,
      ),
    );
  }

  void _openChatbotDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const ChatbotDialog();
      },
    );
  }

void _openSurveyPopup() {
  // fallback to 'Jeep' if no mode selected
  final selectedMode = widget.selectedModes.isNotEmpty ? widget.selectedModes.first : 'Jeep';

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
        distanceKm: 5.0, // or use a real computed distance
        transportMode: selectedMode,
        passengerType: widget.passengerType,
      ),
    ),
  );
}

  Future<void> _addLocationMarker(LatLng location, String address, bool isOrigin) async {
    // Prevent selection in/near water bodies
    final isWater = await GeocodingService.isWaterOrNearWater(location, thresholdMeters: 20);
    if (isWater) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a location on land'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (isOrigin) {
      _controller.originPin = location;
      _controller.originController.text = address;
      if (_controller.destinationPin != null && _controller.destinationPin == location) {
        _controller.destinationPin = null;
        _controller.destinationController.clear();
      }
    } else {
      _controller.destinationPin = location;
      _controller.destinationController.text = address;
      if (_controller.originPin != null && _controller.originPin == location) {
        _controller.originPin = null;
        _controller.originController.clear();
      }
    }
    _checkForAutoTransition();
    if (mounted) setState(() {});
  }

  void _checkForAutoTransition() {
    if (_controller.originPin != null && _controller.destinationPin != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _goToRouteMode();
      });
    }
  }

  void _goToRouteMode() {
    Navigator.pushNamed(
      context,
      '/route-mode',
      arguments: {
        'origin': _controller.originPin,
        'destination': _controller.destinationPin,
        'originAddress': _controller.originController.text,
        'destinationAddress': _controller.destinationController.text,
      },
    ).then((_) {
      _controller.clearRoute();
      if (mounted) setState(() {});
    });
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
            mapController: _controller.mapController,
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
              const CurrentLocationLayer(),
              // Outline of Manila city boundary (no fill)
              if (_manilaBoundary.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _manilaBoundary,
                      color: Colors.red,
                      strokeWidth: 2.5,
                    ),
                  ],
                ),
              if (_controller.routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.routePolyline,
                      color: Colors.blueAccent,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Center pin indicator when in pin-drop mode
          if (_isPinningMode)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 50,
                    ),
                    Container(
                      width: 2,
                      height: 25,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

          // Bottom action sheet while pinning
          if (_isPinningMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pan map to choose a location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: Text(
                          _isPinningOrigin ? 'Set as Origin' : 'Set as Destination',
                          style: const TextStyle(fontSize: 16),
                        ),
                        onPressed: _confirmPinAndReturnToSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isPinningOrigin ? Colors.green : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isPinningMode = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay when fetching a route
          if (_controller.isLoadingRoute)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
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

          // Buttons
          Positioned(
            bottom: 90,
            left: 20,
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
              elevation: 4,
              onPressed: _resetCameraOrientation,
              child: const Icon(Icons.explore),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'user_location_button',
              elevation: 4,
              onPressed: _centerOnUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 210,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'chatbotBtn',
              elevation: 4,
              onPressed: _openChatbotDialog,
              backgroundColor: const Color(0xFF0084FF),
              child: Image.asset(
                'assets/images/chatbot_icon.png',
                width: 70,
                height: 70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build markers for origin, destination, and stops
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_controller.originPin != null) {
      markers.add(
        Marker(
          point: _controller.originPin!,
          width: 30,
          height: 30,
          child: const Icon(Icons.location_on, color: Colors.green, size: 30),
        ),
      );
    }
    if (_controller.destinationPin != null) {
      markers.add(
        Marker(
          point: _controller.destinationPin!,
          width: 30,
          height: 30,
          child: const Icon(Icons.flag, color: Colors.red, size: 30),
        ),
      );
    }
    for (final stop in _controller.routeStops) {
      final lat = stop['lat'] ?? stop['latitude'];
      final lon = stop['lon'] ?? stop['longitude'];
      if (lat != null && lon != null) {
        markers.add(
          Marker(
            point: LatLng(lat.toDouble(), lon.toDouble()),
            width: 12,
            height: 12,
            child: const Icon(Icons.circle, color: Colors.blue, size: 12),
          ),
        );
      }
    }
    return markers;
  }

  TileLayer get openStreetMapTileLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.maiway',
        tileProvider: CancellableNetworkTileProvider(),
      );
}