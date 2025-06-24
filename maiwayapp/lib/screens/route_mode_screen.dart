import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routing_service.dart';
import '../utils/route_processor.dart';
import '../models/route_segment.dart';
import '../screens/navigation_screen.dart';
import '../services/geocoding_service.dart';
import 'package:google_fonts/google_fonts.dart';

class RouteModeScreen extends StatefulWidget {
  @override
  _RouteModeScreenState createState() => _RouteModeScreenState();
}

class _RouteModeScreenState extends State<RouteModeScreen> {
  MapController _mapController = MapController();
  LatLng _originLocation = LatLng(14.5995, 120.9842); // Default Manila
  LatLng _destinationLocation = LatLng(14.5547, 121.0244); // Default Manila
  String _originAddress = '';
  String _destinationAddress = '';
  
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  
  // Route data from backend
  List<Map<String, dynamic>> _routes = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _selectedRoute;
  List<RouteSegment>? _routeSegments;
  List<LatLng>? _routePolyline;
  int _highlightedSegmentIndex = -1;

  // Pinning mode state
  bool _isPinning = false;
  bool _isPinningOrigin = true;
  LatLng _pinLocation = LatLng(14.5995, 120.9842);
  String _pinAddress = '';
  bool _isFetchingPinAddress = false;

  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _originLocation = args['origin'] as LatLng;
          _destinationLocation = args['destination'] as LatLng;
          _originAddress = args['originAddress'] as String;
          _destinationAddress = args['destinationAddress'] as String;
        });
        _fetchRoutesFromBackend();
      } else {
        _fetchRoutesFromBackend();
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) {
      return '$totalSeconds sec';
    }
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String result = '';
    if (hours > 0) {
      result += '${hours} hr ';
    }
    if (minutes > 0 || hours == 0) {
      result += '${minutes} min';
    }
    return result.trim();
  }

  // Helper method to get selected preferences from SharedPreferences
  Future<List<String>> _getSelectedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> selectedPrefs = [];
    
    if (prefs.getBool('pref_fastest') == true) selectedPrefs.add('fastest');
    if (prefs.getBool('pref_cheapest') == true) selectedPrefs.add('cheapest');
    if (prefs.getBool('pref_convenient') == true) selectedPrefs.add('convenient');
    
    // Return all three preferences by default if none are saved yet
    return selectedPrefs.isEmpty ? ['fastest', 'cheapest', 'convenient'] : selectedPrefs;
  }

  // Helper method to get selected modes from SharedPreferences
  Future<List<String>> _getSelectedModes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> selectedModes = [];
    
    if (prefs.getBool('mode_jeep') == true) selectedModes.add('jeepney');
    if (prefs.getBool('mode_bus') == true) selectedModes.add('bus');
    if (prefs.getBool('mode_lrt') == true) selectedModes.add('lrt');
    if (prefs.getBool('mode_tricycle') == true) selectedModes.add('tricycle');
    if (prefs.getBool('mode_lrt2') == true) selectedModes.add('lrt2');
    
    return selectedModes.isEmpty ? ['jeepney', 'bus', 'lrt'] : selectedModes;
  }

  Future<void> _fetchRoutesFromBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print("🔍 Fetching routes from backend...");
      print("📍 Origin: $_originLocation");
      print("📍 Destination: $_destinationLocation");

      // Determine which preferences are selected
      final prefs = await _getSelectedPreferences();
      final modes = await _getSelectedModes();
      
      print("🔍 DEBUG: Selected preferences: $prefs");
      print("🔍 DEBUG: Selected modes: $modes");
      
      List<Map<String, dynamic>> processedRoutes = [];

      if (prefs.contains('fastest')) {
        final fastestRoute = await RoutingService.getRoute(
          startLocation: _originLocation,
          endLocation: _destinationLocation,
          mode: 'fastest',
          modes: modes,
        );
        if (fastestRoute != null && !fastestRoute.containsKey('error')) {
          final processed = RouteProcessor.processRouteResponse(fastestRoute);
          if (processed['success']) {
            processedRoutes.add({
              'type': 'fastest',
              'title': 'Fastest Route',
              'icon': Icons.speed,
              'color': Colors.green,
              'routeData': processed['routeData'],
              'totalTime': _formatDuration(processed['totalTime'] as int? ?? 0),
              'totalCost': processed['totalCost'] ?? 0.0,
              'segments': processed['segments'] ?? [],
              'polyline': processed['polylinePoints'] ?? [],
            });
          }
        }
      }
      if (prefs.contains('cheapest')) {
        final cheapestRoute = await RoutingService.getRoute(
          startLocation: _originLocation,
          endLocation: _destinationLocation,
          mode: 'cheapest',
          modes: modes,
        );
        if (cheapestRoute != null && !cheapestRoute.containsKey('error')) {
          final processed = RouteProcessor.processRouteResponse(cheapestRoute);
          if (processed['success']) {
            processedRoutes.add({
              'type': 'cheapest',
              'title': 'Cheapest Route',
              'icon': Icons.attach_money,
              'color': Colors.orange,
              'routeData': processed['routeData'],
              'totalTime': _formatDuration(processed['totalTime'] as int? ?? 0),
              'totalCost': processed['totalCost'] ?? 0.0,
              'segments': processed['segments'] ?? [],
              'polyline': processed['polylinePoints'] ?? [],
            });
          }
        }
      }
      if (prefs.contains('convenient')) {
        final convenientRoute = await RoutingService.getRoute(
          startLocation: _originLocation,
          endLocation: _destinationLocation,
          mode: 'convenient',
          modes: modes,
        );
        if (convenientRoute != null && !convenientRoute.containsKey('error')) {
          final processed = RouteProcessor.processRouteResponse(convenientRoute);
          if (processed['success']) {
            processedRoutes.add({
              'type': 'convenient',
              'title': 'Most Convenient',
              'icon': Icons.accessibility,
              'color': Colors.purple,
              'routeData': processed['routeData'],
              'totalTime': _formatDuration(processed['totalTime'] as int? ?? 0),
              'totalCost': processed['totalCost'] ?? 0.0,
              'segments': processed['segments'] ?? [],
              'polyline': processed['polylinePoints'] ?? [],
            });
          }
        }
      }

      print("📋 Total processed routes: ${processedRoutes.length}");
      setState(() {
        _routes = processedRoutes;
        _isLoading = false;
        _selectedRouteIndex = processedRoutes.isNotEmpty ? 0 : -1;
        _selectedRoute = processedRoutes.isNotEmpty ? processedRoutes[0] : null;
      });

      if (processedRoutes.isNotEmpty) {
        _setupMapData();
      } else {
        setState(() {
          _errorMessage = 'No routes found for this journey';
          _isLoading = false;
        });
      }

    } catch (e) {
      print("❌ Error fetching routes: $e");
      setState(() {
        _errorMessage = 'Failed to fetch routes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _setupMapData() {
    // Add markers
    _markers = [
      Marker(
        width: 80.0,
        height: 80.0,
        point: _originLocation,
        child: Container(
          child: Icon(
            Icons.radio_button_checked,
            color: Colors.green,
            size: 20,
          ),
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: _destinationLocation,
        child: Container(
          child: Icon(
            Icons.location_on,
            color: Colors.red,
            size: 25,
          ),
        ),
      ),
    ];

    // Add route polyline if routes are available
    if (_routes.isNotEmpty && _selectedRouteIndex < _routes.length) {
      final selectedRoute = _routes[_selectedRouteIndex];
      final polylinePoints = selectedRoute['polyline'] as List<LatLng>? ?? [_originLocation, _destinationLocation];
      
      _polylines = [
        Polyline(
          points: polylinePoints,
          strokeWidth: 4.0,
          color: selectedRoute['color'],
        ),
      ];
    } else {
      // Default polyline
      _polylines = [
        Polyline(
          points: [_originLocation, _destinationLocation],
          strokeWidth: 4.0,
          color: Colors.blue,
        ),
      ];
    }

    // Center map on route
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(
            _originLocation.latitude < _destinationLocation.latitude
                ? _originLocation.latitude
                : _destinationLocation.latitude,
            _originLocation.longitude < _destinationLocation.longitude
                ? _originLocation.longitude
                : _destinationLocation.longitude,
          ),
          LatLng(
            _originLocation.latitude > _destinationLocation.latitude
                ? _originLocation.latitude
                : _destinationLocation.latitude,
            _originLocation.longitude > _destinationLocation.longitude
                ? _originLocation.longitude
                : _destinationLocation.longitude,
          ),
        ),
        padding: EdgeInsets.all(50),
      ),
    );
  }

  void _onRouteSelected(int index) {
    setState(() {
      _selectedRouteIndex = index;
      
      // Update polyline color and points
      if (_routes.isNotEmpty && index < _routes.length) {
        final selectedRoute = _routes[index];
        final polylinePoints = selectedRoute['polyline'] as List<LatLng>? ?? [_originLocation, _destinationLocation];
        
        _polylines = [
          Polyline(
            points: polylinePoints,
            strokeWidth: 4.0,
            color: selectedRoute['color'],
          ),
        ];
      }
    });
  }

  void _showRouteOptions(Map<String, dynamic> routeData) {
    setState(() {
      _selectedRoute = routeData;
      _routeSegments = (routeData['segments'] as List)
          .map((s) => s as RouteSegment)
          .toList();
      _routePolyline = _getPolylineFromSegments(_routeSegments!);
      _highlightedSegmentIndex = -1; // Reset highlight
    });
    _fitBounds(_getBoundsForSegments(_routeSegments!));
  }

  void _startTrip() {
    // If no route is explicitly selected, use the currently selected index
    if (_selectedRoute == null && _routes.isNotEmpty && _selectedRouteIndex < _routes.length) {
      _selectedRoute = _routes[_selectedRouteIndex];
    }
    if (_selectedRoute == null) return;

    // Ensure the polyline for the selected route is passed correctly
    final List<RouteSegment> segments = (_selectedRoute!['segments'] as List)
        .map((s) => s as RouteSegment)
        .toList();
    final List<LatLng> fullPolyline = _getPolylineFromSegments(segments);

    Navigator.pushNamed(
      context,
      '/navigation',
      arguments: {
        'route': _selectedRoute!,
        'origin': _originLocation,
        'destination': _destinationLocation,
        'polyline': fullPolyline,
        'summary': _selectedRoute!['routeData']?['summary'] ?? {},
      },
    ).then((result) {
      // Check if we need to clear pins when returning from navigation
      if (result != null && result is Map<String, dynamic> && result['clearPins'] == true) {
        print('🔄 Clearing pins after returning from navigation');
        // Navigate back to map screen with clear pins flag
        Navigator.of(context).pop({'clearPins': true});
      }
    });
  }

  void _onSegmentTapped(int index) {
    if (_routeSegments == null || index < 0 || index >= _routeSegments!.length) {
      // ... existing code ...
    }
  }

  void _enterPinningMode({required bool isOrigin}) {
    setState(() {
      _isPinning = true;
      _isPinningOrigin = isOrigin;
      _pinLocation = isOrigin ? _originLocation : _destinationLocation;
      _pinAddress = isOrigin ? _originAddress : _destinationAddress;
    });
    _moveMapToPin();
    _fetchPinAddress(_pinLocation);
  }

  void _moveMapToPin() {
    _mapController.move(_pinLocation, 16.0);
  }

  Future<void> _fetchPinAddress(LatLng location) async {
    setState(() { _isFetchingPinAddress = true; });
    try {
      final address = await GeocodingService.getAddressFromLocation(location);
      setState(() {
        _pinAddress = address;
        _isFetchingPinAddress = false;
      });
    } catch (e) {
      setState(() { _pinAddress = 'Unknown location'; _isFetchingPinAddress = false; });
    }
  }

  void _confirmPinLocation() {
    setState(() {
      if (_isPinningOrigin) {
        _originLocation = _pinLocation;
        _originAddress = _pinAddress;
      } else {
        _destinationLocation = _pinLocation;
        _destinationAddress = _pinAddress;
      }
      _isPinning = false;
    });
    _fetchRoutesFromBackend();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top App Bar - Keep MaiwayApp blue header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              bottom: 0,
            ),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isPinning)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => setState(() => _isPinning = false),
                      )
                    else
                      SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'MAIWAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Arial',
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
                // Blue bezel
                Container(
                  height: 8,
                  width: double.infinity,
                  color: Color(0xFF6699CC),
                ),
              ],
            ),
          ),

          // Pinning Mode UI
          if (_isPinning)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isFetchingPinAddress ? 'Loading address...' : _pinAddress,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Do you know information about this place?',
                        style: TextStyle(color: Colors.lightBlue, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmPinLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Plan a Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: 12),
                      FloatingActionButton(
                        heroTag: 'user_location_button',
                        mini: true,
                        elevation: 4,
                        onPressed: _centerOnUserLocation,
                        child: const Icon(Icons.my_location),
                      ),
                      SizedBox(width: 8),
                      FloatingActionButton(
                        heroTag: 'reset_orientation_button',
                        mini: true,
                        elevation: 4,
                        onPressed: _resetCameraOrientation,
                        child: const Icon(Icons.explore),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // Map Section
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _isPinning ? _pinLocation : _originLocation,
                    initialZoom: 15.0,
                    onPositionChanged: (pos, hasGesture) {
                      if (_isPinning && hasGesture) {
                        setState(() {
                          _pinLocation = pos.center!;
                        });
                        _fetchPinAddress(_pinLocation);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.maiwayapp',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    if (_isPinning)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 60.0,
                            height: 60.0,
                            point: _pinLocation,
                            child: Icon(Icons.location_pin, color: Colors.blue, size: 48),
                          ),
                        ],
                      )
                    else ...[
                      PolylineLayer(polylines: _polylines),
                      MarkerLayer(markers: _markers),
                    ],
                  ],
                ),
                
                // Loading Overlay
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Finding routes...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Error Overlay
                if (_errorMessage != null)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        margin: EdgeInsets.all(32),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Route Error',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchRoutesFromBackend,
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Start Trip Button Overlay
                if (!_isPinning && !_isLoading && _errorMessage == null && _routes.isNotEmpty && _selectedRouteIndex >= 0)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: _startTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'START TRIP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom Sheet Content (hide during pinning)
          if (!_isPinning)
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Directions Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                        decoration: BoxDecoration(
                          color: Color(0xFF6699CC),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            Center(
                              child: Text(
                                'DIRECTIONS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Arial',
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Origin and Destination
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => _enterPinningMode(isOrigin: true),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF003366), // dark blue for origin
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 30,
                                color: Colors.grey[300],
                              ),
                              GestureDetector(
                                onTap: () => _enterPinningMode(isOrigin: false),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _originAddress,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _destinationAddress,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.swap_vert, color: Colors.blue),
                            onPressed: () {
                              // Handle swap locations
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                    
                    // Loading/Error/Routes
                    Expanded(
                      child: _buildRoutesSection(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoutesSection() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding best routes...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Could not find routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchRoutesFromBackend,
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Text('No routes found for this journey.'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${_routes.length} suggested routes',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _routes.length,
            itemBuilder: (context, index) {
              final route = _routes[index];
              final isSelected = index == _selectedRouteIndex;
              
              return GestureDetector(
                onTap: () => _onRouteSelected(index),
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? route['color'] : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: route['color'],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              route['icon'],
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: route['color'],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: route['color'].withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: 0.6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: route['color'],
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱ ${route['totalCost'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: route['color'],
                                ),
                              ),
                              Text(
                                route['totalTime'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(route['segments'] as List).length} segments',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- HELPER METHODS ---

  List<LatLng> _getPolylineFromSegments(List<RouteSegment> segments) {
    return segments.expand((s) => s.coordinates).toList();
  }

  LatLngBounds _getBoundsForSegments(List<RouteSegment> segments) {
    final points = _getPolylineFromSegments(segments);
    return LatLngBounds.fromPoints(points);
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(50.0),
      ),
    );
  }
} 