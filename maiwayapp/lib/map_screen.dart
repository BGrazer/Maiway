import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'search_sheet.dart';
import 'controllers/map_screen_controller.dart';
import 'city_boundary.dart';
import 'services/geocoding_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapScreenController controller;
  bool _isLoading = true;
  bool _isPinningMode = false;
  bool _isPinningOrigin = true;

  @override
  void initState() {
    super.initState();
    controller = MapScreenController(
      showError: _showError,
      showSuccess: _showSuccess,
      setState: () => setState(() {}),
    );
    _initializeMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

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

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isPinningMode) {
      return;
    }
  }

  void _confirmPinAndReturnToSearch() {
    final pinnedLocation = controller.mapController.camera.center;
    
    GeocodingService.getAddressFromLocation(pinnedLocation).then((address) {
      if (mounted) {
        if (_isPinningOrigin) {
          controller.originPin = pinnedLocation;
          controller.originController.text = address;
        } else {
          controller.destinationPin = pinnedLocation;
          controller.destinationController.text = address;
        }
        
        if (mounted) {
          setState(() {
            _isPinningMode = false;
          });
        }
        
        _showSearchSheet();
        _checkForAutoTransition();
      }
    }).catchError((_) {
      if (mounted) {
        final fallbackAddress = 'Lat: ${pinnedLocation.latitude.toStringAsFixed(4)}, Lng: ${pinnedLocation.longitude.toStringAsFixed(4)}';
        if (_isPinningOrigin) {
          controller.originPin = pinnedLocation;
          controller.originController.text = fallbackAddress;
        } else {
          controller.destinationPin = pinnedLocation;
          controller.destinationController.text = fallbackAddress;
        }
        if (mounted) {
          setState(() {
            _isPinningMode = false;
          });
        }
        _showSearchSheet();
        _checkForAutoTransition();
      }
    });
  }

  void _checkForAutoTransition() {
    if (controller.originPin != null && controller.destinationPin != null) {
      Future.delayed(Duration(milliseconds: 500), () {
        _goToRouteMode();
      });
    }
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
      controller.clearRoute();
    });
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
    );
  }

  void _addLocationMarker(LatLng location, String address, bool isOrigin) {
    if (isOrigin) {
      controller.originPin = location;
      controller.originController.text = address;
      if (controller.destinationPin != null && controller.destinationPin == location) {
        controller.destinationPin = null;
        controller.destinationController.clear();
      }
    } else {
      controller.destinationPin = location;
      controller.destinationController.text = address;
      if (controller.originPin != null && controller.originPin == location) {
        controller.originPin = null;
        controller.originController.clear();
      }
    }
    _checkForAutoTransition();
  }

  void refreshWithNewPreferences() {
    controller.clearRoute();
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
        actions: [
          // Test connection button for debugging
          IconButton(
            icon: Icon(Icons.wifi_find, color: Colors.black),
            onPressed: () => controller.testBackendConnection(),
            tooltip: 'Test Backend Connection',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialCenter: controller.currentLocation ?? LatLng(14.5995, 120.9842),
              initialZoom: 15.0,
              onTap: _onMapTap,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.maiwayapp',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: getManilaBoundary(),
                    color: Colors.transparent,
                    borderColor: Colors.grey,
                    borderStrokeWidth: 1.0,
                  ),
                ],
              ),
              MarkerLayer(markers: _getMarkers()),
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
            ],
          ),

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
          
          Positioned(
            top: 8,
            left: 7,
            right: 7,
            child: GestureDetector(
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

          if (_isLoading || controller.isLoadingRoute)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),

          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'user_location_button',
              elevation: 4,
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
              onPressed: controller.resetCameraOrientation,
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _getMarkers() {
    List<Marker> markers = [];
    
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
    }
    
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
    }
    
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
    }
    
    return markers;
  }
}