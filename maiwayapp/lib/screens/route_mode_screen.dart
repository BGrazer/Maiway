import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/routing_service.dart';
import '../utils/route_processor.dart';
import '../models/route_segment.dart';
import '../models/transport_mode.dart'; // Ensure this is imported for colors
import 'package:google_fonts/google_fonts.dart';
import 'package:maiwayapp/utils/polyline_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RouteModeScreen extends StatefulWidget {
  @override
  _RouteModeScreenState createState() => _RouteModeScreenState();
}

class _RouteModeScreenState extends State<RouteModeScreen> {
  final MapController _mapController = MapController();
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color accentBlue = const Color(0xFF6699CC);

  LatLng _originLocation = LatLng(14.5995, 120.9842);
  LatLng _destinationLocation = LatLng(14.5547, 121.0244);
  String _originAddress = '';
  String _destinationAddress = '';

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<Map<String, dynamic>> _routes = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // Logic remains untouched to protect functionality
  void _initializeScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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

  // Preference/Mode Fetching Helpers (Logic Protected)
  Future<List<String>> _getSelectedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> selectedPrefs = [];
    if (prefs.getBool('pref_fastest') == true) selectedPrefs.add('fastest');
    if (prefs.getBool('pref_cheapest') == true) selectedPrefs.add('cheapest');
    if (prefs.getBool('pref_convenient') == true)
      selectedPrefs.add('convenient');
    return selectedPrefs.isEmpty ? ['fastest'] : selectedPrefs;
  }

  Future<List<String>> _getSelectedModes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> selectedModes = [];
    if (prefs.getBool('mode_jeepney') == true) selectedModes.add('jeepney');
    if (prefs.getBool('mode_bus') == true) selectedModes.add('bus');
    if (prefs.getBool('mode_lrt') == true) selectedModes.add('lrt');
    if (prefs.getBool('mode_tricycle') == true) selectedModes.add('tricycle');
    return selectedModes.isEmpty ? ['jeepney', 'bus', 'lrt'] : selectedModes;
  }

  Future<String> _getPassengerType() async {
    final prefs = await SharedPreferences.getInstance();
    final type =
        prefs.getString('passengerType') ??
        prefs.getString('passenger_type') ??
        'Regular';
    return type.toLowerCase() == 'discounted' ? 'discounted' : 'regular';
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

      if (prefs.contains('fastest')) {
        final fastest = await _fetchRoute('fastest', modes);
        if (fastest != null)
          processedRoutes.add({
            'type': 'fastest',
            'title': 'Fastest Route',
            'icon': Icons.speed_rounded,
            'color': Colors.green,
            ...fastest,
          });
      }
      if (prefs.contains('cheapest')) {
        final cheapest = await _fetchRoute('cheapest', modes);
        if (cheapest != null)
          processedRoutes.add({
            'type': 'cheapest',
            'title': 'Cheapest Route',
            'icon': Icons.payments_rounded,
            'color': Colors.orange,
            ...cheapest,
          });
      }
      if (prefs.contains('convenient')) {
        final convenient = await _fetchRoute('convenient', modes);
        if (convenient != null)
          processedRoutes.add({
            'type': 'convenient',
            'title': 'Most Convenient',
            'icon': Icons.accessibility_new_rounded,
            'color': Colors.purple,
            ...convenient,
          });
      }

      setState(() {
        _routes = processedRoutes;
        _isLoading = false;
        _selectedRouteIndex = processedRoutes.isNotEmpty ? 0 : -1;
      });

      if (processedRoutes.isNotEmpty)
        _setupMapData();
      else
        setState(() {
          _errorMessage = 'No routes found for this journey';
        });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch routes: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchRoute(
    String mode,
    List<String> modes,
  ) async {
    try {
      final passengerType = await _getPassengerType();
      final prefs = await _getSelectedPreferences();
      final response = await RoutingService.getRoute(
        startLocation: _originLocation,
        endLocation: _destinationLocation,
        mode: mode,
        modes: modes,
        preferences: prefs,
        passengerType: passengerType,
        useGoogle: true,
      );
      if (response != null && !response.containsKey('error')) {
        final processed = RouteProcessor.processRouteResponse(response);
        if (processed['success']) return processed;
      }
    } catch (e) {
      print('🟥 Error fetching $mode route: $e');
    }
    return null;
  }

  void _setupMapData() {
    _markers = [
      Marker(
        point: _originLocation,
        width: 40,
        height: 40,
        child: Icon(Icons.radio_button_checked, color: primaryBlue, size: 24),
      ),
      Marker(
        point: _destinationLocation,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on_rounded,
          color: Colors.red,
          size: 30,
        ),
      ),
    ];

    if (_routes.isNotEmpty && _selectedRouteIndex < _routes.length) {
      final selectedRoute = _routes[_selectedRouteIndex];
      final segments = selectedRoute['segments'] as List<RouteSegment>;
      List<LatLng> polylinePoints = [];
      for (final seg in segments) {
        if (polylinePoints.isNotEmpty &&
            seg.polyline.isNotEmpty &&
            polylinePoints.last == seg.polyline.first) {
          polylinePoints.addAll(seg.polyline.skip(1));
        } else {
          polylinePoints.addAll(seg.polyline);
        }
      }
      if (polylinePoints.isEmpty)
        polylinePoints = [_originLocation, _destinationLocation];

      setState(() {
        _polylines = [
          Polyline(
            points: polylinePoints,
            strokeWidth: 5.0,
            color: selectedRoute['color'],
          ),
        ];
      });

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(polylinePoints),
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  Future<void> _saveTravelHistory(Map<String, dynamic> selectedRoute) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final segments = (selectedRoute['segments'] as List).cast<RouteSegment>();
    final data = {
      'userId': user.uid,
      'modeOfTransport': _collectModes(segments),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'origin': _originAddress,
      'destination': _destinationAddress,
      'distance': (selectedRoute['totalDistance'] ?? 0)
          .toDouble()
          .toStringAsFixed(2),
      'fare': (selectedRoute['totalCost'] ?? 0).toDouble(),
    };
    await FirebaseFirestore.instance.collection('travel_history').add(data);
  }

  String _collectModes(List<RouteSegment> segments) {
    final modes =
        segments
            .map((s) => s.mode.name.toLowerCase())
            .where((m) => m != 'walking')
            .toSet()
            .toList();
    return modes.isEmpty ? 'walking' : modes.join(',');
  }

  Future<void> _startTrip() async {
    if (_routes.isEmpty) return;
    final selectedRoute = _routes[_selectedRouteIndex];
    final passengerType = await _getPassengerType();

    Navigator.pushNamed(
      context,
      '/navigation',
      arguments: {
        'route': selectedRoute['routeData'],
        'origin': _originLocation,
        'destination': _destinationLocation,
        'passengerType':
            passengerType == 'discounted' ? 'Discounted' : 'Regular',
      },
    );
    _saveTravelHistory(selectedRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'MAIWAY ROUTE',
          style: GoogleFonts.montserrat(
            color: primaryBlue,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _originLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.maiwayapp',
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Sliding UI Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildLocationHeader(), _buildRoutesSection()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _locationRow(Icons.circle, Colors.green, _originAddress),
                const SizedBox(height: 8),
                _locationRow(
                  Icons.place_rounded,
                  Colors.red,
                  _destinationAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutesSection() {
    if (_isLoading) return _buildLoading();
    if (_errorMessage != null) return _buildError();

    return Column(
      children: [
        Container(
          height: 320,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _routes.length,
            itemBuilder:
                (context, index) => _buildRouteCard(_routes[index], index),
          ),
        ),
        _buildStartButton(),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, int index) {
    final isSelected = index == _selectedRouteIndex;
    final color = route['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedRouteIndex = index);
        _setupMapData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(route['icon'], color: color, size: 20),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              route['title'].toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '₱${route['totalCost'].toStringAsFixed(0)}',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
              ),
            ),
            Text(
              '${(route['totalDistance'] / 1000).toStringAsFixed(1)} km · ~20 min',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Wrap(
              spacing: 5,
              children:
                  (route['segments'] as List)
                      .map(
                        (s) => Icon(
                          TransportModeHelper.getIcon(s.mode),
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
      child: ElevatedButton(
        onPressed: _startTrip,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'START TRIP',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Padding(
    padding: EdgeInsets.all(50),
    child: Center(child: CircularProgressIndicator()),
  );
  Widget _buildError() => Padding(
    padding: EdgeInsets.all(30),
    child: Text(_errorMessage!, textAlign: TextAlign.center),
  );
}
