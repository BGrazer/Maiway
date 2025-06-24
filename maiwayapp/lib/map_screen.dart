import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maiwayapp/city_boundary.dart';
import 'package:maiwayapp/search_sheet.dart';
import 'search_sheet.dart';
import 'controllers/map_screen_controller.dart';
import 'city_boundary.dart';
import 'services/geocoding_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  late final List<LatLng> _manilaBoundary;

  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  late MapScreenController controller;
  bool _isLoading = true;
  bool _isPinningMode = false;
  bool _isPinningOrigin = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _manilaBoundary = getManilaBoundary();
    controller = MapScreenController(
      showError: _showError,
      showSuccess: _showSuccess,
      setState: () => setState(() {}),
    );
    _initializeMap();
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    super.dispose();
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will be called when the widget is rebuilt, including after preference changes
    print('🔄 DEBUG: MapScreen dependencies changed, checking for preference updates');
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _initializeMap() async {
    await controller.getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

    if (permission == LocationPermission.deniedForever) return;
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isPinningMode) {
      // Tapping the map does nothing during pinning mode.
      // Confirmation is done via a dedicated button.
      return;
    }
  }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
  void _confirmPinAndReturnToSearch() {
    final pinnedLocation = controller.mapController.camera.center;
    
    print('📍 DEBUG: Pinning location: ${pinnedLocation.latitude}, ${pinnedLocation.longitude}');
    print('📍 DEBUG: Is pinning origin: $_isPinningOrigin');
    
    // Reverse geocode to get the address
    GeocodingService.getAddressFromLocation(pinnedLocation).then((address) {
      if (mounted) {
        if (_isPinningOrigin) {
          controller.originPin = pinnedLocation;
          controller.originController.text = address;
          print('✅ DEBUG: Origin pin saved: ${controller.originPin?.latitude}, ${controller.originPin?.longitude}');
          print('✅ DEBUG: Origin address: ${controller.originController.text}');
        } else {
          controller.destinationPin = pinnedLocation;
          controller.destinationController.text = address;
          print('✅ DEBUG: Destination pin saved: ${controller.destinationPin?.latitude}, ${controller.destinationPin?.longitude}');
          print('✅ DEBUG: Destination address: ${controller.destinationController.text}');
        }
        
        if (mounted) {
          setState(() {
            _isPinningMode = false;
          });
        }
        
        // Return to the search sheet
        _showSearchSheet();
        _checkForAutoTransition(); // Check if we can now find a route
      }
    }).catchError((_) {
      // Fallback if geocoding fails
      if (mounted) {
        final fallbackAddress = 'Lat: ${pinnedLocation.latitude.toStringAsFixed(4)}, Lng: ${pinnedLocation.longitude.toStringAsFixed(4)}';
        if (_isPinningOrigin) {
          controller.originPin = pinnedLocation;
          controller.originController.text = fallbackAddress;
          print('✅ DEBUG: Origin pin saved (fallback): ${controller.originPin?.latitude}, ${controller.originPin?.longitude}');
        } else {
          controller.destinationPin = pinnedLocation;
          controller.destinationController.text = fallbackAddress;
          print('✅ DEBUG: Destination pin saved (fallback): ${controller.destinationPin?.latitude}, ${controller.destinationPin?.longitude}');
        }
        if (mounted) {
          setState(() {
            _isPinningMode = false;
          });
        }
        // Return to the search sheet
        _showSearchSheet();
        _checkForAutoTransition();
      }
    });
  }

  void _centerOnUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
      _mapController.rotate(0);
  void _checkForAutoTransition() {
    print('🔍 DEBUG: Checking auto transition...');
    print('🔍 DEBUG: Origin pin: ${controller.originPin?.latitude}, ${controller.originPin?.longitude}');
    print('🔍 DEBUG: Destination pin: ${controller.destinationPin?.latitude}, ${controller.destinationPin?.longitude}');
    
    if (controller.originPin != null && controller.destinationPin != null) {
      print('✅ DEBUG: Both pins set, auto-transitioning to route mode');
      // Auto transition to route mode after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        _goToRouteMode();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to fetch location')));
      print('❌ DEBUG: Not all pins set yet');
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
  void _goToRouteMode() {
    Navigator.pushNamed(
      context, 
      '/route-mode',
      arguments: {
        'origin': controller.originPin,
        'destination': controller.destinationPin,
        'originAddress': controller.originController.text,
        'destinationAddress': controller.destinationController.text,
      },
    ).then((result) {
      // Check if we need to clear pins when returning from route mode
      if (result != null && result is Map<String, dynamic> && result['clearPins'] == true) {
        print('🔄 Clearing pins after returning from route mode');
        controller.clearRoute();
      }
    });
  }

  /// Opens the search sheet for origin and destination input.
  void _openSearchSheet() {
  void _showSearchSheet() {
    // Do not clear pins and controllers automatically here
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      backgroundColor: Colors.transparent,
      builder: (context) => SearchSheet(
        onLocationSelected: (LatLng location, String address, bool isOrigin) {
          _addLocationMarker(location, address, isOrigin);
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
        currentLocation: controller.currentLocation ?? LatLng(14.5995, 120.9842),
        originAddress: controller.originController.text,
        destinationAddress: controller.destinationController.text,
      ),
      builder:
          (context) => SearchSheet(
            originController: originController,
            destinationController: destinationController,
          ),
    );
  }

  void _addLocationMarker(LatLng location, String address, bool isOrigin) {
    print('📍 DEBUG: Adding location marker - isOrigin: $isOrigin');
    print('📍 DEBUG: Location: ${location.latitude}, ${location.longitude}');
    print('📍 DEBUG: Address: $address');
    
    if (isOrigin) {
      controller.originPin = location;
      controller.originController.text = address;
      print('✅ DEBUG: Origin pin set: ${controller.originPin?.latitude}, ${controller.originPin?.longitude}');
      // If origin is set, clear destination if it matches the new origin
      if (controller.destinationPin != null && controller.destinationPin == location) {
        controller.destinationPin = null;
        controller.destinationController.clear();
        print('🔄 DEBUG: Cleared destination pin (same as origin)');
      }
    } else {
      controller.destinationPin = location;
      controller.destinationController.text = address;
      print('✅ DEBUG: Destination pin set: ${controller.destinationPin?.latitude}, ${controller.destinationPin?.longitude}');
      // If destination is set, clear origin if it matches the new destination
      if (controller.originPin != null && controller.originPin == location) {
        controller.originPin = null;
        controller.originController.clear();
        print('🔄 DEBUG: Cleared origin pin (same as destination)');
      }
    }
    _checkForAutoTransition();
  }

  // Method to refresh the map screen when preferences change
  void refreshWithNewPreferences() {
    print('🔄 DEBUG: Refreshing map screen with new preferences');
    // Clear any existing routes to force refresh with new preferences
    controller.clearRoute();
    
    // Re-initialize the map if needed
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
        title: Text(
          'MAIWAY',
          style: GoogleFonts.notoSerif(
            fontSize: 24,
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF6699CC),
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            mapController: controller.mapController,
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
              initialCenter: controller.currentLocation ?? LatLng(14.5995, 120.9842),
              initialZoom: 15.0,
              onTap: _onMapTap,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              openStreetMapTileLayer,
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.maiwayapp',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              // Manila City Boundary (Red Border)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _manilaBoundary,
                    color: Colors.transparent,
                    borderColor: Colors.redAccent,
                    borderStrokeWidth: 3,
                    points: getManilaBoundary(),
                    color: Colors.red.withOpacity(0.1),
                    borderColor: Colors.red,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),
<<<<<<< Updated upstream
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
=======
              MarkerLayer(markers: _getMarkers()),
              // Add route polyline if available
              if (controller.routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: controller.routePolyline,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
              ),
>>>>>>> Stashed changes
            ],
          ),

          // Center Pin Icon when in Pinning Mode
          if (_isPinningMode)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _isPinningOrigin ? Colors.blue : Colors.red,
                      size: 50,
                    ),
                    Container(
                      width: 2,
                      height: 25,
                      color: _isPinningOrigin ? Colors.blue : Colors.red,
                    )
                  ],
                ),
              ),
            ),
          
          // Search Bar
          Positioned(
            top: 7,
            top: 8, // Move even closer to the AppBar
            left: 7,
            right: 7,
            child: GestureDetector(
              onTap: _openSearchSheet,
              onTap: _showSearchSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
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

          // Buttons for user location and camera orientation
          // Pinning Mode Controls
          if (_isPinningMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pan map to choose a location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                            ),
                          ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.location_on),
                          label: Text(
                            _isPinningOrigin ? 'Set as Origin' : 'Set as Destination',
                            style: TextStyle(fontSize: 16),
                          ),
                          onPressed: _confirmPinAndReturnToSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPinningOrigin ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextButton(
                        child: Text('Cancel'),
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
          ),

          // Loading Indicator
          if (_isLoading || controller.isLoadingRoute)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),

          // Add full-size floating action buttons to the lower right
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'user_location_button',
              elevation: 4,
              onPressed: _centerOnUserLocation,
              onPressed: controller.centerOnUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'reset_orientation_button',
              elevation: 4,
              onPressed: _resetCameraOrientation,
              onPressed: controller.resetCameraOrientation,
              child: const Icon(Icons.explore),
              ),
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
    List<Marker> markers = [];
    
    print('🎯 DEBUG: Creating markers...');
    
    // Current location marker
    if (controller.currentLocation != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: controller.currentLocation!,
          child: Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
      print('🎯 DEBUG: Added current location marker');
    }
    
    // Origin marker
    if (controller.originPin != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: controller.originPin!,
          child: Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
      print('🎯 DEBUG: Added origin marker at ${controller.originPin!.latitude}, ${controller.originPin!.longitude}');
    } else {
      print('🎯 DEBUG: No origin pin to display');
    }
    
    // Destination marker
    if (controller.destinationPin != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: controller.destinationPin!,
          child: Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
      print('🎯 DEBUG: Added destination marker at ${controller.destinationPin!.latitude}, ${controller.destinationPin!.longitude}');
    } else {
      print('🎯 DEBUG: No destination pin to display');
    }
    
    print('🎯 DEBUG: Total markers created: ${markers.length}');
    return markers;
  }
}