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
import 'package:maiwayapp/utils/polyline_utils.dart';
import 'package:maiwayapp/widgets/labeled_marker.dart';

/// RouteModeScreen displays available route alternatives and lets the user select one to navigate.
class RouteModeScreen extends StatefulWidget {
  @override
  _RouteModeScreenState createState() => _RouteModeScreenState();
}

/// State for RouteModeScreen, manages route fetching and selection.
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
  bool _showAllPolylines = true; // new flag

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

      // --- NEW COMBINED REQUEST ---
      final response = await RoutingService.getMultiCriteriaRoutes(
        startLocation: _originLocation,
        endLocation: _destinationLocation,
        modes: modes,
        preferences: prefs,
      );

      if (response == null || response.containsKey('error')) {
        throw Exception(response?['error'] ?? 'Unknown error');
      }

      final Map<String, dynamic> routeSummaries =
          Map<String, dynamic>.from(response['route_summaries'] ?? {});

      List<Map<String, dynamic>> processedRoutes = [];

      Map<String, Map<String, dynamic>> prefMeta = {
        'fastest': {
          'title': 'Fastest Route',
          'icon': Icons.speed,
          'color': Colors.green,
        },
        'cheapest': {
          'title': 'Cheapest Route',
          'icon': Icons.attach_money,
          'color': Colors.orange,
        },
        'convenient': {
          'title': 'Most Convenient',
          'icon': Icons.accessibility,
          'color': Colors.purple,
        },
      };

      for (final pref in ['fastest', 'cheapest', 'convenient']) {
        if (!prefs.contains(pref)) continue; // user did not request this pref

        final segmentsList = response[pref];
        if (segmentsList is List && segmentsList.isNotEmpty) {
          // Build a fake sub-response compatible with RouteProcessor
          final subResponse = {
            pref: segmentsList,
            'summary': routeSummaries[pref] ?? response['summary'] ?? {},
          };
          final processed = RouteProcessor.processRouteResponse(subResponse);
          if (processed['success']) {
            processedRoutes.add({
              'type': pref,
              'title': prefMeta[pref]!['title'],
              'icon': prefMeta[pref]!['icon'],
              'color': prefMeta[pref]!['color'],
              'routeData': processed['routeData'],
              'totalCost': processed['totalCost'] ?? 0.0,
              'segments': processed['segments'] ?? [],
              'polylinePoints': processed['polylinePoints'] ?? [],
            });
          }
        }
      }

      // Ensure list order is fastest→cheapest→convenient
      processedRoutes.sort((a, b) =>
          ['fastest', 'cheapest', 'convenient']
              .indexOf(a['type'])
              .compareTo(
                  ['fastest', 'cheapest', 'convenient'].indexOf(b['type'])));

      setState(() {
        _routes = processedRoutes;
        _isLoading = false;
        _selectedRouteIndex = processedRoutes.isNotEmpty ? 0 : -1;
      });

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
        _errorMessage = 'Failed to fetch routes: \n${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<LatLng> parsePolyline(dynamic polyline) {
    return PolylineUtils.parsePolyline(polyline);
  }

  List<LatLng> robustPolyline(dynamic polyline, LatLng origin, LatLng destination) {
    return PolylineUtils.robustPolyline(polyline, origin, destination);
  }

  void _setupMapData() {
    // Add markers using labeled markers
    _markers = [
      Marker(
        width: 80.0,
        height: 80.0,
        point: _originLocation,
        child: LabeledMarker(
          label: 'Start',
          color: Colors.blue,
        ),
      ),
      Marker(
        width: 80.0,
        height: 80.0,
        point: _destinationLocation,
        child: LabeledMarker(
          label: 'End',
            color: Colors.red,
        ),
      ),
    ];

    // Draw polylines for all routes or just selected route
    _polylines = [];
    if (_showAllPolylines) {
      for (int i = 0; i < _routes.length; i++) {
        final route = _routes[i];
        final polylinePoints = robustPolyline(route['polylinePoints'], _originLocation, _destinationLocation);
        _polylines.add(
          Polyline(
            points: polylinePoints,
            strokeWidth: i == _selectedRouteIndex ? 4.0 : 2.0,
            color: route['color'].withOpacity(i == _selectedRouteIndex ? 1.0 : 0.3),
          ),
        );
      }
    } else if (_selectedRouteIndex >= 0 && _selectedRouteIndex < _routes.length) {
      final route = _routes[_selectedRouteIndex];
      final polylinePoints = robustPolyline(route['polylinePoints'], _originLocation, _destinationLocation);
      _polylines = [
        Polyline(
          points: polylinePoints,
          strokeWidth: 4.0,
          color: route['color'],
        ),
      ];
    }

    // Center map on route
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([_originLocation, _destinationLocation]),
        padding: EdgeInsets.all(50),
      ),
    );
  }

  void _onRouteSelected(int index) {
    setState(() {
      _selectedRouteIndex = index;
      _showAllPolylines = false;
      _setupMapData();
    });
  }

  void _startTrip() {
    if (_routes.isEmpty || _selectedRouteIndex < 0 || _selectedRouteIndex >= _routes.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a route first')),
      );
      return;
    }

    final selectedRoute = _routes[_selectedRouteIndex];
    Navigator.pushNamed(
      context,
      '/navigation',
      arguments: {
        'route': selectedRoute['routeData'],
        'origin': _originLocation,
        'destination': _destinationLocation,
        'summary': selectedRoute['routeData']?['summary'] ?? {},
        'routeColor': selectedRoute['color'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map takes full screen
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
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Bottom sheet with DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
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
                child: SingleChildScrollView(
                  controller: scrollController,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Drag handle
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Start Trip Button
                  Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6699CC),
                          foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
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
                      // Origin and Destination Section
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: const Color(0xFF6699CC)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          SizedBox(width: 8),
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: Colors.blue,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _originAddress,
                                  style: TextStyle(
                                      fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _destinationAddress,
                                  style: TextStyle(
                                      fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                      // Routes Section (no nested scroll view)
                      _buildRoutesSection(),
                  ],
                ),
              ),
              );
            },
            ),
        ],
      ),
    );
  }

  Widget _buildRoutesSection() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6699CC)),
            ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 20),
              Text(
              'No routes found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6699CC),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _fetchRoutesFromBackend,
              ),
            ],
        ),
      );
    }

    if (_routes.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, color: Colors.grey, size: 64),
            SizedBox(height: 20),
            Text(
              'No routes found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'No routes found for this journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6699CC),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _fetchRoutesFromBackend,
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            '${_routes.length} suggested routes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        ListView.builder(
            shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _routes.length,
            itemBuilder: (context, index) {
              final route = _routes[index];
              return _buildRouteCard(route, index);
            },
        ),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, int index) {
    final isSelected = index == _selectedRouteIndex;
    final segments = route['segments'] as List<RouteSegment>? ?? [];
    final totalCost = route['totalCost'] as double? ?? 0.0;
    
    // Calculate route statistics
    double totalDistance = 0.0;
    Map<String, int> modeCount = {};
    
    for (final segment in segments) {
      totalDistance += segment.distance;
      final mode = segment.mode.name;
      modeCount[mode] = (modeCount[mode] ?? 0) + 1;
    }
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? route['color'].withOpacity(0.1) : Colors.white,
      child: InkWell(
        onTap: () => _onRouteSelected(index),
        child: Padding(
          padding: EdgeInsets.all(12),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // Route header
                      Row(
                        children: [
                  Icon(route['icon'], color: route['color'], size: 20),
                  SizedBox(width: 8),
                          Expanded(
                    child: Text(
                                  route['title'],
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                                    color: route['color'],
                                  ),
                                ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: route['color'], size: 20),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Route statistics
                                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                  Text(
                      '₱${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '${(totalDistance/1000).toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                                ),
                              ],
                            ),
              
              if (modeCount.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: modeCount.entries.map((entry) {
                    final mode = entry.key;
                    final count = entry.value;
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getModeColor(mode).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(
                            _getModeIcon(mode),
                            size: 14,
                            color: _getModeColor(mode),
                          ),
                          SizedBox(width: 2),
                              Text(
                            '$mode ($count)',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getModeColor(mode),
                                ),
                              ),
                            ],
                          ),
                    );
                  }).toList(),
                      ),
              ],
                    ],
          ),
                  ),
                ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'lrt':
        return Colors.red;
      case 'bus':
        return Colors.blue;
      case 'jeep':
        return Colors.orange;
      case 'tricycle':
        return Colors.purple;
      case 'walking':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'lrt':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'jeep':
        return Icons.local_taxi;
      case 'tricycle':
        return Icons.motorcycle;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.directions;
    }
  }
}