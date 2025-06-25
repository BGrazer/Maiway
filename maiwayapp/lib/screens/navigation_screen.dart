import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';
import '../models/transport_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_entry.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  MapController _mapController = MapController();
  
  // Navigation data
  List<RouteSegment> _segments = [];
  List<LatLng> _fullPolyline = [];
  LatLng? _origin;
  LatLng? _destination;
  Map<String, dynamic>? _routeData;
  Map<String, dynamic>? _summary;
  
  // Navigation state
  int _currentStepIndex = 0;
  bool _isTripStarted = false;
  bool _isTripEnded = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  void _initializeNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (args == null) {
        setState(() {
          _errorMessage = 'No navigation data provided';
          _isLoading = false;
        });
        return;
      }

      print('🟦 Navigation args: $args');
      
      try {
        // Extract and validate arguments
        _origin = args['origin'] as LatLng?;
        _destination = args['destination'] as LatLng?;
        _routeData = args['route'] != null ? fixMap(args['route']) : null;
        _summary = args['summary'] != null ? fixMap(args['summary']) : null;
        
        // Extract polyline
        if (args['polyline'] != null) {
          _fullPolyline = robustPolyline(args['polyline'], _origin!, _destination!);
          print('🟦 Full polyline loaded: ${_fullPolyline.length} points');
        }
        
        // Extract segments from route data
        if (_routeData != null) {
          final rawSegments = _routeData!['segments'] as List?;
          if (rawSegments != null && rawSegments.isNotEmpty) {
            _segments = rawSegments.map((s) {
              if (s is Map<String, dynamic>) {
                return RouteSegment.fromMap(s);
              } else if (s is Map) {
                return RouteSegment.fromMap(fixMap(s));
              } else if (s is RouteSegment) {
                return s;
              } else {
                return null;
              }
            }).whereType<RouteSegment>().toList();
            print('🟦 Segments loaded: ${_segments.length} segments');
          }
        }
        
        // Validate we have at least origin and destination
        if (_origin == null || _destination == null) {
          setState(() {
            _errorMessage = 'Missing origin or destination coordinates';
            _isLoading = false;
          });
          return;
        }
        
        // If no polyline, create a simple one from origin to destination
        if (_fullPolyline.isEmpty) {
          _fullPolyline = [_origin!, _destination!];
          print('🟦 Created fallback polyline: origin to destination');
        }
        
        // If no segments, create a simple walking segment
        if (_segments.isEmpty) {
          _segments = [
            RouteSegment(
              mode: TransportMode.fromString('walking'),
              instruction: 'Walk to destination',
              name: 'Walking',
              coordinates: [_origin!, _destination!],
              distance: _calculateDistance(_origin!, _destination!),
              fromStop: 'Origin',
              toStop: 'Destination',
            ),
          ];
          print('🟦 Created fallback walking segment');
        }
        
        setState(() {
          _isLoading = false;
        });
        
        // Setup map after data is loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setupMap();
        });
        
      } catch (e) {
        print('🟥 Error initializing navigation: $e');
        setState(() {
          _errorMessage = 'Failed to load navigation data: ${e.toString()}';
          _isLoading = false;
        });
      }
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    // Simple distance calculation (not exact but good enough for display)
    const double earthRadius = 6371000; // meters
    final lat1 = start.latitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final deltaLat = (end.latitude - start.latitude) * (math.pi / 180);
    final deltaLon = (end.longitude - start.longitude) * (math.pi / 180);
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
              math.cos(lat1) * math.cos(lat2) * math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final c = 2 * math.atan(math.sqrt(a) / math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  void _setupMap() {
    if (!mounted) return;
    
    try {
      if (_fullPolyline.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_fullPolyline),
            padding: EdgeInsets.all(50.0),
          ),
        );
      } else if (_origin != null && _destination != null) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(_origin!, _destination!),
            padding: EdgeInsets.all(50.0),
          ),
        );
      }
    } catch (e) {
      print('🟥 Error setting up map: $e');
      if (_origin != null) {
        _mapController.move(_origin!, 15.0);
      }
    }
  }

  void _nextStep() {
    if (_segments.isNotEmpty && _currentStepIndex < _segments.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _focusOnStep(_currentStepIndex);
    } else if (_currentStepIndex >= _segments.length - 1) {
      _endTrip();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _focusOnStep(_currentStepIndex);
    }
  }
  
  void _focusOnStep(int stepIndex) {
    if (stepIndex < _segments.length) {
      final segment = _segments[stepIndex];
      if (segment.coordinates.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              final bounds = LatLngBounds.fromPoints(segment.coordinates);
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: EdgeInsets.all(50.0),
                ),
              );
            } catch (e) {
              print('🟥 Error focusing on step: $e');
            }
          }
        });
      }
    }
  }

  void _endTrip() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Trip Completed!'),
          content: Text('You have reached your destination.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Color _getSegmentColor(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('walk')) return Colors.grey;
    if (m.contains('jeep')) return Colors.blue;
    if (m.contains('bus')) return Colors.green;
    if (m.contains('tricycle')) return Colors.orange;
    if (m.contains('lrt')) return Colors.purple;
    return Colors.grey;
  }

  Future<void> saveTripToFirestore(TripEntry entry, String collection) async {
    try {
      await FirebaseFirestore.instance.collection(collection).add(entry.toMap());
      print('🟦 Trip saved to $collection');
    } catch (e) {
      print('🟥 Error saving trip: $e');
    }
  }

  TripEntry _createTripEntryFromSummary(Map<String, dynamic> summary) {
    String transportModeStr(dynamic code) {
      switch (code) {
        case 2:
          return 'Jeepney';
        case 4:
          return 'Tricycle';
        case 5:
          return 'Walk';
        default:
          return code.toString();
      }
    }
    
    return TripEntry(
      km: (summary['total_distance'] as num?)?.toDouble() ?? 0.0,
      transportMode: transportModeStr(summary['transport_mode']),
      routeTaken: summary['route_taken'] ?? '',
      routeType: summary['preference'] ?? '',
      preference: summary['preference'] ?? '',
      passengerType: summary['passenger_type'] ?? '',
      fare: (summary['total_cost'] as num?)?.toDouble() ?? 0.0,
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF6699CC),
          elevation: 0,
          automaticallyImplyLeading: true,
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
                    'NAVIGATION',
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6699CC)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading navigation...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF6699CC),
          elevation: 0,
          automaticallyImplyLeading: true,
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
                    'NAVIGATION',
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Could not load navigation data.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6699CC),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6699CC),
        elevation: 0,
        automaticallyImplyLeading: true,
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
                  'NAVIGATION',
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
              initialCenter: _origin ?? LatLng(14.5995, 120.9842),
              initialZoom: 15.0,
              onMapReady: () => _setupMap(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.maiwayapp',
              ),
              // Show full route polyline
              if (_fullPolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _fullPolyline,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              // Highlight current segment
              if (_segments.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < _segments.length; i++)
                      if (_segments[i].coordinates.length >= 2)
                        Polyline(
                          points: _segments[i].coordinates,
                          strokeWidth: i == _currentStepIndex ? 8.0 : 4.0,
                          color: _getSegmentColor(_segments[i].mode.name),
                          borderColor: i == _currentStepIndex ? Colors.black : Colors.transparent,
                          borderStrokeWidth: i == _currentStepIndex ? 2.0 : 0.0,
                        ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_origin != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _origin!,
                      child: Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFF003366),
                        size: 20,
                      ),
                    ),
                  if (_destination != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _destination!,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 25,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Step counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _segments.isNotEmpty 
                          ? 'Step ${_currentStepIndex + 1} of ${_segments.length}'
                          : 'Navigation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Current instruction
                  if (_segments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          // Transport mode indicator
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getSegmentColor(_segments[_currentStepIndex].mode.name).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getSegmentColor(_segments[_currentStepIndex].mode.name),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _segments[_currentStepIndex].mode.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getSegmentColor(_segments[_currentStepIndex].mode.name),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _segments[_currentStepIndex].instruction,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Navigation buttons
                  if (_segments.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _currentStepIndex > 0 ? _previousStep : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6699CC),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Previous',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _currentStepIndex < _segments.length - 1 ? _nextStep : _endTrip,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentStepIndex == _segments.length - 1 ? Colors.green : const Color(0xFF6699CC),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              _currentStepIndex == _segments.length - 1 ? 'End Trip' : 'Next',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> fixMap(dynamic map) =>
    map is Map<String, dynamic> ? map : Map<String, dynamic>.from(map as Map);

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