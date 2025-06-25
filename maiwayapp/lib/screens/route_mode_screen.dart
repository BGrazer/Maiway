import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routing_service.dart';
import '../utils/route_processor.dart';
import '../models/route_segment.dart';
import '../models/transport_mode.dart';
import '../screens/navigation_screen.dart';
import '../services/geocoding_service.dart';
import 'package:google_fonts/google_fonts.dart';

class RouteModeScreen extends StatefulWidget {
  @override
  _RouteModeScreenState createState() => _RouteModeScreenState();
}

class _RouteModeScreenState extends State<RouteModeScreen> {
  MapController _mapController = MapController();
  
  // Location data
  LatLng _originLocation = LatLng(14.5995, 120.9842); // Default Manila
  LatLng _destinationLocation = LatLng(14.5547, 121.0244); // Default Manila
  String _originAddress = '';
  String _destinationAddress = '';
  
  // Map data
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  
  // Route data
  List<Map<String, dynamic>> _routes = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _originLocation = args['origin'] as LatLng;
          _destinationLocation = args['destination'] as LatLng;
          _originAddress = args['originAddress'] as String;
          _destinationAddress = args['destinationAddress'] as String;
        });
      }
      _fetchRoutesFromBackend();
    });
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
    
    if (prefs.getBool('mode_jeepney') == true) selectedModes.add('jeepney');
    if (prefs.getBool('mode_bus') == true) selectedModes.add('bus');
    if (prefs.getBool('mode_lrt') == true) selectedModes.add('lrt');
    if (prefs.getBool('mode_tricycle') == true) selectedModes.add('tricycle');
    
    return selectedModes.isEmpty ? ['jeepney', 'bus', 'lrt'] : selectedModes;
  }

  Future<void> _fetchRoutesFromBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await _getSelectedPreferences();
      final modes = await _getSelectedModes();
      
      List<Map<String, dynamic>> processedRoutes = [];

      // Fetch fastest route
      if (prefs.contains('fastest')) {
        final fastestRoute = await _fetchRoute('fastest', modes);
        if (fastestRoute != null) {
            processedRoutes.add({
              'type': 'fastest',
              'title': 'Fastest Route',
              'icon': Icons.speed,
              'color': Colors.green,
            'routeData': fastestRoute['routeData'],
            'totalCost': fastestRoute['totalCost'] ?? 0.0,
            'segments': fastestRoute['segments'] ?? [],
            'polylinePoints': fastestRoute['polylinePoints'] ?? [],
          });
        }
      }

      // Fetch cheapest route
      if (prefs.contains('cheapest')) {
        final cheapestRoute = await _fetchRoute('cheapest', modes);
        if (cheapestRoute != null) {
            processedRoutes.add({
              'type': 'cheapest',
              'title': 'Cheapest Route',
              'icon': Icons.attach_money,
              'color': Colors.orange,
            'routeData': cheapestRoute['routeData'],
            'totalCost': cheapestRoute['totalCost'] ?? 0.0,
            'segments': cheapestRoute['segments'] ?? [],
            'polylinePoints': cheapestRoute['polylinePoints'] ?? [],
          });
        }
      }

      // Fetch convenient route
      if (prefs.contains('convenient')) {
        final convenientRoute = await _fetchRoute('convenient', modes);
        if (convenientRoute != null) {
            processedRoutes.add({
              'type': 'convenient',
              'title': 'Most Convenient',
              'icon': Icons.accessibility,
              'color': Colors.purple,
            'routeData': convenientRoute['routeData'],
            'totalCost': convenientRoute['totalCost'] ?? 0.0,
            'segments': convenientRoute['segments'] ?? [],
            'polylinePoints': convenientRoute['polylinePoints'] ?? [],
          });
        }
      }

      setState(() {
        _routes = processedRoutes;
        _isLoading = false;
        _selectedRouteIndex = processedRoutes.isNotEmpty ? 0 : -1;
      });

      print('🟦 Processed ${processedRoutes.length} routes');
      for (int i = 0; i < processedRoutes.length; i++) {
        final route = processedRoutes[i];
        print('🟦 Route $i: ${route['title']} - ${route['polylinePoints']?.length ?? 0} points');
      }

      if (processedRoutes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMapData();
        });
      } else {
        setState(() {
          _errorMessage = 'No routes found for this journey';
          _isLoading = false;
        });
      }

    } catch (e) {
      print('🟥 Error fetching routes: $e');
      setState(() {
        _errorMessage = 'Failed to fetch routes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchRoute(String mode, List<String> modes) async {
    try {
      final response = await RoutingService.getRoute(
        startLocation: _originLocation,
        endLocation: _destinationLocation,
        mode: mode,
        modes: modes,
      );
      
      print('🟦 $mode RAW RESPONSE: $response');
      
      if (response != null && !response.containsKey('error')) {
        final processed = RouteProcessor.processRouteResponse(response);
        print('🟩 $mode PROCESSED: $processed');
        
        if (processed['success']) {
          return processed;
        } else {
          print('❌ $mode route not added: ${processed['error']?.toString() ?? 'Unknown error'}');
        }
      } else {
        print('❌ $mode route not added: error or null response');
      }
    } catch (e) {
      print('🟥 Error fetching $mode route: $e');
    }
    
    return null;
  }

  List<LatLng> parsePolyline(dynamic polyline) {
    if (polyline is List<LatLng>) return polyline;
    if (polyline is List) {
      return polyline.map((p) {
        if (p is LatLng) return p;
        if (p is List && p.length == 2) {
          return LatLng(p[1].toDouble(), p[0].toDouble());
        }
        if (p is Map && p.containsKey('latitude') && p.containsKey('longitude')) {
          return LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
        }
        throw Exception('Invalid polyline point: $p');
      }).toList();
    }
    return [];
  }

  List<LatLng> robustPolyline(dynamic polyline, LatLng origin, LatLng destination) {
    final parsed = parsePolyline(polyline);
    if (parsed.isEmpty) {
      print('🟥 Polyline empty, using fallback [origin, destination]');
      return [origin, destination];
    }
    final first = parsed.first;
    final allSame = parsed.every((p) => p.latitude == first.latitude && p.longitude == first.longitude);
    if (allSame) {
      print('🟥 Polyline all points same, using fallback [origin, destination]');
      return [origin, destination];
    }
    return parsed;
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

    // Add route polyline
    if (_routes.isNotEmpty && _selectedRouteIndex < _routes.length) {
      final selectedRoute = _routes[_selectedRouteIndex];
      final polylinePoints = robustPolyline(selectedRoute['polylinePoints'], _originLocation, _destinationLocation);
      print('🟦 Setting up polyline with ${polylinePoints.length} points');
      _polylines = [
        Polyline(
          points: polylinePoints,
          strokeWidth: 4.0,
          color: selectedRoute['color'],
        ),
      ];
    } else {
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
        final polylinePoints = robustPolyline(selectedRoute['polylinePoints'], _originLocation, _destinationLocation);
        print('🟦 Route selected: ${selectedRoute['title']} with ${polylinePoints.length} points');
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

  void _startTrip() {
    if (_routes.isEmpty || _selectedRouteIndex < 0 || _selectedRouteIndex >= _routes.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a route first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedRoute = _routes[_selectedRouteIndex];
    
    // Ensure we have valid segments and polyline
    final List<RouteSegment> segments = (selectedRoute['segments'] as List)
        .map((s) => s as RouteSegment)
        .toList();
    
    final List<LatLng> polylinePoints = robustPolyline(selectedRoute['polylinePoints'], _originLocation, _destinationLocation);

    print('🟦 Starting trip with ${segments.length} segments and ${polylinePoints.length} polyline points');

    Navigator.pushNamed(
      context,
      '/navigation',
      arguments: {
        'route': selectedRoute,
        'origin': _originLocation,
        'destination': _destinationLocation,
        'polyline': polylinePoints,
        'summary': selectedRoute['routeData']?['summary'] ?? {},
      },
    ).then((result) {
      if (result != null && result is Map<String, dynamic> && result['clearPins'] == true) {
        print('🔄 Clearing pins after returning from navigation');
        Navigator.of(context).pop({'clearPins': true});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6699CC),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'MAIWAY',
              style: GoogleFonts.notoSerif(
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'ROUTE',
                  style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _originLocation,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(
                polylines: _polylines,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),

          // Bottom Sheet Content
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // START TRIP BUTTON
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6699CC),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                  ),
                  
                    // Origin and Destination Section with Back Button
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          // Back Button
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: const Color(0xFF6699CC)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          SizedBox(width: 8),
                          // Origin/Destination Markers
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(0xFF003366), // dark blue for origin
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 30,
                                color: Colors.grey[300],
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 16),
                          // Location Text
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
                                SizedBox(height: 16),
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
                          // Swap Button
                          IconButton(
                            icon: Icon(Icons.swap_vert, color: const Color(0xFF6699CC)),
                            onPressed: () {
                              // Handle swap locations
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: _buildRoutesSection(),
                      ),
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
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6699CC)),
            ),
            SizedBox(height: 16),
            Text(
              'Finding best routes...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6699CC),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No routes found for this journey.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRoutesFromBackend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6699CC),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${_routes.length} suggested routes',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: ListView.builder(
            shrinkWrap: true,
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
                    mainAxisSize: MainAxisSize.min,
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
} 