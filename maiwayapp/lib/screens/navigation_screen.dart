import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';
import '../models/transport_mode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../utils/route_processor.dart';
import '../utils/polyline_utils.dart';

Map<String, dynamic> fixMap(dynamic map) {
  if (map is Map<String, dynamic>) return map;
  if (map is Map) return Map<String, dynamic>.from(map);
  return {};
}

List<LatLng> parsePolyline(dynamic polyline) {
  return PolylineUtils.parsePolyline(polyline);
}

List<LatLng> robustPolyline(dynamic polyline, LatLng origin, LatLng destination) {
  return PolylineUtils.robustPolyline(polyline, origin, destination);
}

List<LatLng> getPolylineFromRoute(dynamic route, LatLng origin, LatLng destination) {
  // Try to get polyline from different possible sources
  if (route is Map) {
    // Try shapes first (new format)
    if (route.containsKey('shapes')) {
      final shapes = route['shapes'];
      if (shapes is List && shapes.isNotEmpty) {
        print('🟦 Using shapes for polyline');
        return robustPolyline(shapes, origin, destination);
      }
    }
    
    // Try polylinePoints (processed format)
    if (route.containsKey('polylinePoints')) {
      final polylinePoints = route['polylinePoints'];
      if (polylinePoints is List && polylinePoints.isNotEmpty) {
        print('🟦 Using polylinePoints for polyline');
        return robustPolyline(polylinePoints, origin, destination);
      }
    }
  }
  
  // Fallback to origin-destination line
  print('🟦 Using fallback polyline [origin, destination]');
  return [origin, destination];
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({Key? key}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late List<RouteSegment> _segments;
  late List<LatLng> _fullPolyline;
  late LatLng _origin;
  late LatLng _destination;
  int _currentStep = 0;
  bool _loading = true;
  String? _error;
  MapController _mapController = MapController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initNavigation();
  }

  void _initNavigation() {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final map = fixMap(args);
      final route = fixMap(map['route']);
      final summary = fixMap(map['summary']);
      
      // Robustly handle origin and destination
      if (map['origin'] is LatLng) {
        _origin = map['origin'];
      } else if (map['origin'] is List) {
        final originPoints = PolylineUtils.parsePolyline(map['origin']);
        if (originPoints.isNotEmpty) {
          _origin = originPoints.first;
        } else {
          throw Exception('Invalid origin format: ' + map['origin'].toString());
        }
      } else {
        throw Exception('Invalid origin format: ' + map['origin'].toString());
      }
      if (map['destination'] is LatLng) {
        _destination = map['destination'];
      } else if (map['destination'] is List) {
        final destPoints = PolylineUtils.parsePolyline(map['destination']);
        if (destPoints.isNotEmpty) {
          _destination = destPoints.first;
        } else {
          throw Exception('Invalid destination format: ' + map['destination'].toString());
        }
      } else {
        throw Exception('Invalid destination format: ' + map['destination'].toString());
      }
      
      // Get segments from the selected route type
      final segmentsRaw = (route['segments'] ?? route['fastest'] ?? route['cheapest'] ?? route['convenient']) as List?;
      
      if (segmentsRaw != null) {
        print('🟦 NavigationScreen: Processing ${segmentsRaw.length} raw segments');
        _segments = segmentsRaw.map((seg) {
          if (seg is RouteSegment) {
            return seg;
          } else {
            final s = fixMap(seg);
            // Create polyline for this segment
            List<LatLng> segPolyline = [];
            if (s['polyline'] != null) {
              segPolyline = PolylineUtils.parsePolyline(s['polyline']);
            } else {
              // Create simple polyline from stop coordinates
              final fromLat = s['from_stop']?['lat'] ?? _origin.latitude;
              final fromLon = s['from_stop']?['lon'] ?? _origin.longitude;
              final toLat = s['to_stop']?['lat'] ?? _destination.latitude;
              final toLon = s['to_stop']?['lon'] ?? _destination.longitude;
              segPolyline = [LatLng(fromLat, fromLon), LatLng(toLat, toLon)];
            }
            return RouteSegment(
              mode: TransportMode.fromString(s['mode']?.toString() ?? 'unknown'),
              instruction: s['instruction'] ?? _getInstruction(s['mode']?.toString() ?? 'unknown', s['from_stop']?['name'], s['to_stop']?['name']),
              name: s['name'] ?? s['route_id'] ?? '',
              coordinates: segPolyline,
              polyline: segPolyline,
              distance: (s['distance'] ?? 0).toDouble(),
              fare: (s['fare'] ?? 0).toDouble(),
              fromStop: s['from_stop']?['name'] ?? s['from'] ?? 'Origin',
              toStop: s['to_stop']?['name'] ?? s['to'] ?? 'Destination',
              detailedInstructions: s['detailed_instructions'] ?? [],
            );
          }
        }).toList();
      } else {
        print('🟦 NavigationScreen: No segments found, creating fallback');
        _segments = [
          RouteSegment(
            mode: TransportMode.fromString('walking'),
            instruction: 'Walk to your destination',
            name: 'Walk',
            coordinates: [_origin, _destination],
            polyline: [_origin, _destination],
            distance: 0,
            fare: 0,
            fromStop: 'Origin',
            toStop: 'Destination',
            detailedInstructions: [],
          )
        ];
      }
      
      // Build the full route polyline from all segments
      _fullPolyline = _segments.expand((seg) => seg.polyline).toList();
      if (_fullPolyline.isEmpty) {
        _fullPolyline = [_origin, _destination];
      }
      
      print('🟦 NavigationScreen: Final segments count = ${_segments.length}');
      
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      print('🟦 NavigationScreen error: $e\n$st');
      setState(() {
        _loading = false;
        _error = 'Failed to load navigation data: $e';
      });
    }
  }

  String _getInstruction(String mode, String? fromStop, String? toStop) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return 'Walk to ${toStop ?? 'destination'}';
      case 'jeep':
      case 'jeepney':
        return 'Take jeepney to ${toStop ?? 'next stop'}';
      case 'bus':
        return 'Take bus to ${toStop ?? 'next stop'}';
      case 'lrt':
        return 'Take LRT to ${toStop ?? 'next stop'}';
      case 'tricycle':
        return 'Take tricycle to ${toStop ?? 'next stop'}';
      default:
        return 'Travel to ${toStop ?? 'destination'}';
    }
  }

  void _nextStep() {
    if (_currentStep < _segments.length - 1) {
      setState(() => _currentStep++);
      _centerMapOnCurrentSegment();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _centerMapOnCurrentSegment();
    }
  }

  void _centerMapOnCurrentSegment() {
    if (_currentStep < _segments.length) {
      final segment = _segments[_currentStep];
      if (segment.polyline.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.coordinates(coordinates: segment.polyline),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Navigation'),
          backgroundColor: const Color(0xFF6699CC),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: const Color(0xFF6699CC)),
              SizedBox(height: 16),
              Text('Loading route...', style: GoogleFonts.montserrat(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Navigation Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Navigation Error',
                  style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.montserrat(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_segments.isEmpty || _currentStep >= _segments.length) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Navigation'),
          backgroundColor: const Color(0xFF6699CC),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'No route segments available.',
            style: GoogleFonts.montserrat(fontSize: 16),
          ),
        ),
      );
    }
    
    final segment = _segments[_currentStep];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation'),
        backgroundColor: const Color(0xFF6699CC),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: segment.polyline.isNotEmpty ? segment.polyline.first : _origin,
                initialZoom: 15.0,
                onMapReady: () {
                  _centerMapOnCurrentSegment();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                // Current segment polyline (highlighted) - only this one
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: segment.polyline,
                      color: TransportModeHelper.getColor(segment.mode),
                      strokeWidth: 6,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Origin marker
                    Marker(
                      point: _origin,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_on, color: Colors.green, size: 32),
                    ),
                    // Destination marker
                    Marker(
                      point: _destination,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.flag, color: Colors.red, size: 32),
                    ),
                    // Current segment markers
                    if (segment.polyline.isNotEmpty) ...[
                      Marker(
                        point: segment.polyline.first,
                        width: 30,
                        height: 30,
                        child: Icon(Icons.circle, color: TransportModeHelper.getColor(segment.mode), size: 24),
                      ),
                      Marker(
                        point: segment.polyline.last,
                        width: 30,
                        height: 30,
                        child: Icon(Icons.circle, color: TransportModeHelper.getColor(segment.mode), size: 24),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Navigation Info Section
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Progress indicator and segment info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6699CC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Step ${_currentStep + 1} / ${_segments.length}',
                            style: GoogleFonts.montserrat(
                              fontSize: 14, 
                              fontWeight: FontWeight.w600, 
                              color: Colors.white
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              TransportModeHelper.getIcon(segment.mode), 
                              color: TransportModeHelper.getColor(segment.mode),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              TransportModeHelper.getDisplayName(segment.mode),
                              style: GoogleFonts.montserrat(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600, 
                                color: TransportModeHelper.getColor(segment.mode)
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Instruction
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TransportModeHelper.getColor(segment.mode).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TransportModeHelper.getColor(segment.mode).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        segment.instruction.isNotEmpty ? segment.instruction : 'Proceed to next stop',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 18, 
                          fontWeight: FontWeight.w600, 
                          color: TransportModeHelper.getColor(segment.mode)
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Distance and fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pin_drop, color: Colors.blue, size: 18),
                              SizedBox(width: 4),
                              Text(
                                '${segment.distance.toStringAsFixed(1)} km', 
                                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_money, color: Colors.green, size: 18),
                              SizedBox(width: 4),
                              Text(
                                '₱${segment.fare.toStringAsFixed(2)}', 
                                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 12),
                    
                    // From and to stops
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trip_origin, color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'From: ${segment.fromStop}', 
                                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'To: ${segment.toStop}', 
                                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Navigation controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _currentStep > 0 ? _prevStep : null,
                          icon: Icon(Icons.arrow_back),
                          label: Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStep > 0 ? const Color(0xFF6699CC) : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _currentStep < _segments.length - 1 ? _nextStep : null,
                          icon: Icon(Icons.arrow_forward),
                          label: Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStep < _segments.length - 1 ? const Color(0xFF6699CC) : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    
                    // End trip button for last step
                    if (_currentStep == _segments.length - 1)
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.flag),
                          label: Text('End Trip'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}