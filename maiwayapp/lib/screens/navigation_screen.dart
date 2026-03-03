import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';
import '../models/transport_mode.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/polyline_utils.dart';
import 'package:maiwayapp/survey_page.dart';

// Helper functions remain unchanged to protect logic
Map<String, dynamic> fixMap(dynamic map) {
  if (map is Map<String, dynamic>) return map;
  if (map is Map) return Map<String, dynamic>.from(map);
  return {};
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({Key? key}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Theme Colors
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color accentBlue = const Color(0xFF6699CC);

  late List<RouteSegment> _segments;
  late List<LatLng> _fullPolyline;
  late LatLng _origin;
  late LatLng _destination;
  int _currentStep = 0;
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();
  String _passengerType = 'Regular';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initNavigation();
  }

  // --- Logic remains protected as requested ---
  void _initNavigation() {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final map = fixMap(args);
      final route = fixMap(map['route']);
      _passengerType =
          (map['passengerType']?.toString() ?? 'Regular').isEmpty
              ? 'Regular'
              : map['passengerType'].toString();

      if (map['origin'] is LatLng) {
        _origin = map['origin'];
      } else {
        _origin = PolylineUtils.parsePolyline(map['origin']).first;
      }

      if (map['destination'] is LatLng) {
        _destination = map['destination'];
      } else {
        _destination = PolylineUtils.parsePolyline(map['destination']).first;
      }

      final segmentsRaw =
          (route['segments'] ??
                  route['fastest'] ??
                  route['cheapest'] ??
                  route['convenient'])
              as List?;

      if (segmentsRaw != null) {
        _segments =
            segmentsRaw.map((seg) {
              if (seg is RouteSegment) return seg;
              final s = fixMap(seg);
              List<LatLng> segPolyline =
                  s['polyline'] != null
                      ? PolylineUtils.parsePolyline(s['polyline'])
                      : [
                        LatLng(
                          s['from_stop']?['lat'] ?? _origin.latitude,
                          s['from_stop']?['lon'] ?? _origin.longitude,
                        ),
                        LatLng(
                          s['to_stop']?['lat'] ?? _destination.latitude,
                          s['to_stop']?['lon'] ?? _destination.longitude,
                        ),
                      ];

              return RouteSegment(
                mode: TransportMode.fromString(
                  s['mode']?.toString() ?? 'unknown',
                ),
                instruction:
                    s['instruction'] ??
                    _getInstruction(
                      s['mode']?.toString() ?? 'unknown',
                      s['from_stop']?['name'],
                      s['to_stop']?['name'],
                    ),
                name: s['name'] ?? s['route_id'] ?? '',
                coordinates: segPolyline,
                polyline: segPolyline,
                distance: (s['distance'] ?? 0).toDouble(),
                fare: (s['fare'] ?? 0).toDouble(),
                fromStop: s['from_stop']?['name'] ?? s['from'] ?? 'Origin',
                toStop: s['to_stop']?['name'] ?? s['to'] ?? 'Destination',
                detailedInstructions: s['detailed_instructions'] ?? [],
              );
            }).toList();
      } else {
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
          ),
        ];
      }

      _fullPolyline = _segments.expand((seg) => seg.polyline).toList();
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
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
          CameraFit.coordinates(
            coordinates: segment.polyline,
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScreen();
    if (_error != null) return _buildErrorScreen();

    final segment = _segments[_currentStep];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildNavigationHeader(),
      body: Column(
        children: [
          // Map Section with rounded bottom corners
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      segment.polyline.isNotEmpty
                          ? segment.polyline.first
                          : _origin,
                  initialZoom: 15.0,
                  onMapReady: _centerMapOnCurrentSegment,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.yourname.maiwayapp',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _fullPolyline,
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 4,
                      ),
                      Polyline(
                        points: segment.polyline,
                        color: TransportModeHelper.getColor(segment.mode),
                        strokeWidth: 8,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _origin,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.trip_origin,
                          color: Colors.green,
                          size: 28,
                        ),
                      ),
                      Marker(
                        point: _destination,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Modern Navigation Dashboard
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(),
                const SizedBox(height: 15),
                _buildInstructionCard(segment),
                const SizedBox(height: 15),
                _buildTripStats(segment),
                const SizedBox(height: 20),
                _buildControlButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNavigationHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.chevron_left, color: primaryBlue, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'NAVIGATION',
        style: GoogleFonts.montserrat(
          color: primaryBlue,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(_segments.length, (index) {
        bool isPast = index < _currentStep;
        bool isCurrent = index == _currentStep;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? primaryBlue
                      : (isPast ? accentBlue : Colors.grey[200]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInstructionCard(RouteSegment segment) {
    Color modeColor = TransportModeHelper.getColor(segment.mode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: modeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: modeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
            child: Icon(
              TransportModeHelper.getIcon(segment.mode),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransportModeHelper.getDisplayName(
                    segment.mode,
                  ).toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: modeColor,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  segment.instruction,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStats(RouteSegment segment) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem(
          Icons.straighten_rounded,
          '${segment.distance.toStringAsFixed(1)} KM',
          'Distance',
        ),
        Container(width: 1, height: 30, color: Colors.grey[200]),
        _statItem(
          Icons.payments_rounded,
          '₱${segment.fare.toStringAsFixed(2)}',
          'Fare Cost',
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accentBlue),
            const SizedBox(width: 5),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    bool isLast = _currentStep == _segments.length - 1;
    return Row(
      children: [
        if (_currentStep > 0)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filled(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: primaryBlue,
                padding: const EdgeInsets.all(15),
              ),
            ),
          ),
        Expanded(
          child: ElevatedButton(
            onPressed: isLast ? _endTrip : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? Colors.green[600] : primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              isLast ? 'FINISH TRIP' : 'NEXT STEP',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _endTrip() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SurveyPage(
                passengerType: _passengerType,
                tripSegments: _segments,
              ),
            ),
          ),
    );
    if (mounted) Navigator.pop(context);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Preparing your route...',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
