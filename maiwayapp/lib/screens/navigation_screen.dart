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
  List<LatLng> _fullPolyline = [];
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
          final rawSegments = routeData['segments'] as List?;
          if (rawSegments != null && rawSegments.isNotEmpty) {
            _segments = rawSegments.map((s) {
              if (s is Map<String, dynamic>) {
                return RouteSegment.fromMap(s);
              } else if (s is RouteSegment) {
                return s;
              } else {
                return null;
              }
            }).whereType<RouteSegment>().toList();
          }
          _origin = args['origin'] as LatLng?;
          _destination = args['destination'] as LatLng?;
        });
        if (_segments.isNotEmpty) {
          _focusOnStep(0);
        }
      }
    });
  }

  void _setupMap() {
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
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.all(50.0),
          ),
        );
      }
    }
  }

  Color _getSegmentColor(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('walk')) return Color(0xFFFBC531);
    if (m.contains('jeep')) return Color(0xFF00A8FF);
    if (m.contains('bus')) return Color(0xFF8C7AE6);
    if (m.contains('tricycle')) return Color(0xFF4CD137);
    if (m.contains('lrt')) return Color(0xFFE84118);
    return Colors.grey;
  }

  Future<void> saveTripToFirestore(TripEntry entry, String collection) async {
    await FirebaseFirestore.instance.collection(collection).add(entry.toMap());
  }

  void _onStartTrip(TripEntry entry) async {
    await saveTripToFirestore(entry, 'travel_history');
    Navigator.pushReplacementNamed(context, '/travel-history');
  }

  void _onEndTrip(TripEntry entry) async {
    await saveTripToFirestore(entry, 'survey');
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    Navigator.pushReplacementNamed(context, '/survey');
  }

  TripEntry _createTripEntryFromSummary(Map<String, dynamic> summary) {
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
            ],
          ),
        ),
      );
    }

    final currentStep = _segments.isNotEmpty ? _segments[_currentStepIndex] : null;
    final isLastStep = _currentStepIndex == _segments.length - 1;

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
              initialCenter: _origin!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.maiwayapp',
              ),
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
                      color: Color(0xFF003366),
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
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Step ${_currentStepIndex + 1} of ${_segments.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (currentStep != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        currentStep.instruction,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  
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
                          onPressed: !isLastStep ? _nextStep : null,
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
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
                          padding: EdgeInsets.symmetric(vertical: 16),
                          minimumSize: Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'End Trip',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
} 