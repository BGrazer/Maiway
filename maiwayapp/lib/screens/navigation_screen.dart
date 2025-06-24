import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_entry.dart';
import 'package:google_fonts/google_fonts.dart';

class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  MapController _mapController = MapController();
  List<RouteSegment> _segments = [];
  List<LatLng> _fullPolyline = []; // To store the complete route path
  LatLng? _origin;
  LatLng? _destination;
  Color _routeColor = Colors.blue;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['route'] != null) {
        final routeData = args['route'] as Map<String, dynamic>;
        setState(() {
          // Ensure segments are parsed from map if needed
          final rawSegments = routeData['segments'] as List?;
          if (rawSegments != null && rawSegments.isNotEmpty) {
            _segments = rawSegments.map((s) {
              if (s is Map<String, dynamic>) {
                return RouteSegment.fromMap(s);
              } else if (s is RouteSegment) {
                return s;
              } else {
                print('⚠️ Unknown segment type: $s');
                return null;
              }
            }).whereType<RouteSegment>().toList();
          }
          _origin = args['origin'] as LatLng?;
          _destination = args['destination'] as LatLng?;
        });
        print('🔍 NavigationScreen: Loaded ${_segments.length} segments');
        for (var i = 0; i < _segments.length; i++) {
          print('  Segment $i: mode=${_segments[i].mode}, coords=${_segments[i].coordinates.length}');
        }
        // Auto-zoom to first segment
        if (_segments.isNotEmpty) {
          _focusOnStep(0);
        }
      }
    });
  }

  void _setupMap() {
    // Use the full polyline for fitting the map view
    if (_fullPolyline.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_fullPolyline),
              padding: EdgeInsets.all(50.0),
            ),
          );
        }
      });
    } else if (_origin != null && _destination != null) {
      // Fallback to origin/destination if full polyline is empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(_origin!, _destination!),
              padding: EdgeInsets.all(50.0),
            ),
          );
         }
      });
    }
  }

  void _nextStep() {
    if (_segments.isNotEmpty && _currentStepIndex < _segments.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _focusOnStep(_currentStepIndex);
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
        final bounds = LatLngBounds.fromPoints(segment.coordinates);
        print('🔍 Auto-zooming to segment $stepIndex, ${segment.coordinates.length} points');
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.all(50.0),
          ),
        );
      } else {
        print('⚠️ Segment $stepIndex has no coordinates');
      }
    }
  }

  // Robust color mapping for segment modes
  Color _getSegmentColor(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('walk')) return Color(0xFFFBC531); // Yellow
    if (m.contains('jeep')) return Color(0xFF00A8FF); // Blue
    if (m.contains('bus')) return Color(0xFF8C7AE6); // Purple
    if (m.contains('tricycle')) return Color(0xFF4CD137); // Green
    if (m.contains('lrt')) return Color(0xFFE84118); // Orange
    return Colors.grey;
  }

  // Add this function to save a trip entry to Firestore
  Future<void> saveTripToFirestore(TripEntry entry, String collection) async {
    await FirebaseFirestore.instance.collection(collection).add(entry.toMap());
  }

  // Example usage in your Start Trip and End Trip button handlers:

  void _onStartTrip(TripEntry entry) async {
    await saveTripToFirestore(entry, 'travel_history');
    // Navigate to Travel History screen
    Navigator.pushReplacementNamed(context, '/travel-history');
  }

  void _onEndTrip(TripEntry entry) async {
    await saveTripToFirestore(entry, 'survey');
    // Clear pins after ending trip
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    // Access the map screen controller and clear pins/controllers
    // (Assuming you have a way to access the controller, e.g., via a singleton or provider)
    // Example:
    // MapScreenController.instance.clearPinsAndControllers();
    // Or pass the controller via arguments/context if needed
    // Then navigate to the survey screen
    Navigator.pushReplacementNamed(context, '/survey');
  }

  TripEntry _createTripEntryFromSummary(Map<String, dynamic> summary) {
    // Map transport mode code to string
    String transportModeStr(dynamic code) {
      switch (code) {
        case 2:
          return 'Jeep';
        case 4:
          return 'Tricycle';
        case 5:
          return 'Walking';
        default:
          return code.toString();
      }
    }
    return TripEntry(
      km: (summary['distance_km'] as num?)?.toDouble() ?? 0.0,
      transportMode: transportModeStr(summary['transport_mode']),
      routeTaken: summary['route_taken'] ?? '',
      routeType: summary['preference'] ?? '',
      preference: summary['preference'] ?? '',
      passengerType: summary['passenger_type'] ?? '',
      fare: (summary['fare'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final summary = args != null && args['summary'] != null ? Map<String, dynamic>.from(args['summary']) : <String, dynamic>{};
    if (_segments.isEmpty || _origin == null || _destination == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF6699CC),
          elevation: 0,
          automaticallyImplyLeading: true,
          titleSpacing: 0,
          title: Row(
            children: [
              Text(
                'MAIWAY',
                style: GoogleFonts.notoSerif(
                  fontSize: 22,
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
          child: Text('Could not load navigation data.'),
        ),
      );
    }

    final currentStep = _segments.isNotEmpty ? _segments[_currentStepIndex] : null;
    final isLastStep = _currentStepIndex == _segments.length - 1;
    
    // Debug: print if any segment has empty coordinates
    for (var i = 0; i < _segments.length; i++) {
      if (_segments[i].coordinates.isEmpty) {
        print('⚠️ Segment $i has empty coordinates!');
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6699CC),
        elevation: 0,
        automaticallyImplyLeading: true,
        titleSpacing: 0,
        title: Row(
          children: [
            Text(
              'MAIWAY',
              style: GoogleFonts.notoSerif(
                fontSize: 22,
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
          // Fullscreen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _origin!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.maiwayapp',
              ),
              // Render all segment polylines with their colors
              PolylineLayer(
                polylines: [
                  for (final segment in _segments)
                    if (segment.coordinates.length >= 2)
                      Polyline(
                        points: segment.coordinates,
                        strokeWidth: 6.0,
                        color: _getSegmentColor(segment.mode.toString()),
                        borderColor: segment == _segments[_currentStepIndex] ? Colors.black : Colors.transparent,
                        borderStrokeWidth: segment == _segments[_currentStepIndex] ? 3.0 : 0.0,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: _origin!,
                    child: Icon(
                      Icons.radio_button_checked,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
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
          // Directions/steps as a bottom overlay panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Step ${_currentStepIndex + 1} of ${_segments.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Current step instruction
                  if (currentStep != null)
                    Text(
                      currentStep.instruction,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _currentStepIndex > 0 ? _previousStep : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed: !isLastStep ? _nextStep : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                  if (isLastStep)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          final tripEntry = _createTripEntryFromSummary(summary);
                          _onEndTrip(tripEntry);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('End Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    // MapScreenController.instance.clearPinsAndControllers();
    super.dispose();
  }
} 