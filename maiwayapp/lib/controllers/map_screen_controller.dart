import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maiwayapp/services/routing_service.dart';
import 'package:maiwayapp/utils/route_processor.dart';
import 'package:maiwayapp/services/geocoding_service.dart';
import 'package:maiwayapp/utils/geocoding_helper.dart';
import 'package:maiwayapp/city_boundary.dart';
import 'package:maiwayapp/models/route_segment.dart';

class MapScreenController {
  final MapController mapController = MapController();
  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  
  final Function(String) showError;
  final Function(String) showSuccess;
  final Function() setState;
  
  // Add mounted flag to prevent setState after dispose
  bool _mounted = true;
  
  LatLng? currentLocation;
  List<LatLng> routePolyline = [];
  List<RouteSegment> routeSegments = [];
  LatLng? originPin;
  LatLng? destinationPin;
  bool isSelectingOrigin = false;
  bool isSelectingDestination = false;
  bool showOriginSheet = false;
  bool showDestinationSheet = false;
  bool isLoadingRoute = false;
  String currentSearchMode = '';

  // Route information
  Map<String, dynamic>? currentRoute;
  List<Map<String, dynamic>> routeStops = [];
  double? totalCost;
  String? routeError;

  // Manila boundary
  List<LatLng> get manilaBoundary => getManilaBoundary();

  MapScreenController({
    required this.showError,
    required this.showSuccess,
    required this.setState,
  });

  // Safe setState method that checks if controller is still mounted
  void _safeSetState() {
    if (_mounted) {
      setState();
    }
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

  Future<void> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      currentLocation = LatLng(position.latitude, position.longitude);
      _safeSetState();
      
      mapController.move(currentLocation!, 15.0);
    } catch (e) {
      // Handle error silently
    }
  }

  void centerOnUserLocation() {
    if (currentLocation != null) {
      mapController.move(currentLocation!, 15.0);
      mapController.rotate(0);
    } else {
      showError('Unable to fetch location');
    }
  }

  void resetCameraOrientation() {
    mapController.rotate(0);
  }

  void onMapTap(TapPosition tapPosition, LatLng location) {
    if (!GeocodingHelper.isWithinManila(location, manilaBoundary)) {
      showError('Please select a location within Manila city limits');
      return;
    }

    if (isSelectingOrigin) {
      originPin = location;
      isSelectingOrigin = false;
      _safeSetState();
      getAddressFromLocation(location, true);
    } else if (isSelectingDestination) {
      destinationPin = location;
      isSelectingDestination = false;
      _safeSetState();
      getAddressFromLocation(location, false);
    }
  }

  Future<void> getAddressFromLocation(LatLng location, bool isOrigin) async {
    try {
      final address = await GeocodingService.getAddressFromLocation(location);
      
      if (isOrigin) {
        originController.text = address;
      } else {
        destinationController.text = address;
      }
      _safeSetState();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> fetchRoute(String origin, String destination) async {
    if (originPin == null || destinationPin == null) {
      showError("Please select both origin and destination");
      return;
    }

    isLoadingRoute = true;
    routeError = null;
    routePolyline.clear();
    currentRoute = null;
    routeStops.clear();
    _safeSetState();

    try {
      final selectedPrefs = await _getSelectedPreferences();
      final selectedModes = await _getSelectedModes();
      
      final response = await RoutingService.getRoute(
        startLocation: originPin!,
        endLocation: destinationPin!,
        mode: selectedPrefs.isNotEmpty ? selectedPrefs[0] : 'fastest',
        modes: selectedModes,
      );

      // Use RouteProcessor to process the response
      final processedResult = RouteProcessor.processRouteResponse(response);
      
      if (!processedResult['success']) {
        throw Exception(processedResult['error']);
      }

      // Extract processed data
      final routeData = processedResult['routeData'];
      final polylinePoints = processedResult['polylinePoints'] as List<LatLng>;
      final segments = processedResult['segments'] as List<RouteSegment>? ?? [];
      final stops = processedResult['stops'] as List<Map<String, dynamic>>;
      final cost = processedResult['totalCost'] as double?;

      // Update state with successful route
      currentRoute = routeData;
      routePolyline = polylinePoints;
      routeSegments = segments;
      routeStops = stops;
      totalCost = cost;
      
      // Set pins to first and last points if not already set
      if (originPin == null && polylinePoints.isNotEmpty) {
        originPin = polylinePoints.first;
      }
      if (destinationPin == null && polylinePoints.isNotEmpty) {
        destinationPin = polylinePoints.last;
      }
      _safeSetState();

      // Fit map to show entire route
      if (polylinePoints.length >= 2) {
        try {
          final bounds = LatLngBounds.fromPoints(polylinePoints);
          mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50.0),
            ),
          );
        } catch (e) {
          print("⚠️ Error fitting camera: $e");
          mapController.move(polylinePoints.first, 14.0);
        }
      } else if (polylinePoints.isNotEmpty) {
        mapController.move(polylinePoints.first, 15.0);
      }

      showSuccess("Route found successfully!");
      
    } catch (e) {
      print("❌ Route fetch error: $e");
      routeError = e.toString();
      _safeSetState();
      showError("Failed to get route: ${e.toString()}");
    } finally {
      isLoadingRoute = false;
      _safeSetState();
    }
  }

  void clearRoute() {
    print('🧹 DEBUG: Clearing route and pins...');
    print('🧹 DEBUG: Before clear - Origin pin: ${originPin?.latitude}, ${originPin?.longitude}');
    print('🧹 DEBUG: Before clear - Destination pin: ${destinationPin?.latitude}, ${destinationPin?.longitude}');
    
    routePolyline.clear();
    routeSegments.clear();
    originPin = null;
    destinationPin = null;
    currentRoute = null;
    routeStops.clear();
    totalCost = null;
    routeError = null;
    originController.clear();
    destinationController.clear();
    
    print('🧹 DEBUG: After clear - Origin pin: ${originPin?.latitude}, ${originPin?.longitude}');
    print('🧹 DEBUG: After clear - Destination pin: ${destinationPin?.latitude}, ${destinationPin?.longitude}');
    
    _safeSetState();
  }

  /// Center map on a specific route segment
  void centerOnSegment(RouteSegment segment) {
    if (segment.coordinates.isNotEmpty) {
      try {
        final bounds = LatLngBounds.fromPoints(segment.coordinates);
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
        );
      } catch (e) {
        print("⚠️ Error centering on segment: $e");
        // Fallback to center of first coordinate
        mapController.move(segment.coordinates.first, 15.0);
      }
    }
  }

  /// Get all coordinates from all segments for the complete route polyline
  List<LatLng> getAllSegmentCoordinates() {
    final List<LatLng> allCoordinates = [];
    for (final segment in routeSegments) {
      allCoordinates.addAll(segment.coordinates);
    }
    return allCoordinates;
  }

  void openOriginSheet() {
    currentSearchMode = 'origin';
    showOriginSheet = true;
    showDestinationSheet = false;
    _safeSetState();
  }

  void openDestinationSheet() {
    currentSearchMode = 'destination';
    showDestinationSheet = true;
    showOriginSheet = false;
    _safeSetState();
  }

  void selectSuggestion(dynamic suggestion) async {
    final location = suggestion is Map<String, dynamic> 
        ? await GeocodingService.getLocationFromAddress(suggestion['description'])
        : LatLng(suggestion.latitude, suggestion.longitude);
    
    if (location == null) {
      showError("Location not found");
      return;
    }
    
    if (GeocodingHelper.isWithinManila(location, manilaBoundary)) {
      final address = suggestion is Map<String, dynamic> 
          ? suggestion['description'] 
          : suggestion.name;
          
      if (currentSearchMode == 'origin') {
        originController.text = address;
        originPin = location;
        showOriginSheet = false;
      } else {
        destinationController.text = address;
        destinationPin = location;
        showDestinationSheet = false;
      }
      _safeSetState();
      
      mapController.move(location, 15.0);
    } else {
      showError('Selected location is outside Manila');
    }
  }

  void onPlaceSelected(String place, bool isOrigin) async {
    try {
      final location = await GeocodingService.getLocationFromAddress(place);
      
      if (location == null) {
        showError("Location not found");
        return;
      }
      
      if (GeocodingHelper.isWithinManila(location, manilaBoundary)) {
        if (isOrigin) {
          originPin = location;
          originController.text = place;
          showOriginSheet = false;
        } else {
          destinationPin = location;
          destinationController.text = place;
          showDestinationSheet = false;
        }
        _safeSetState();
        
        mapController.move(location, 15.0);
      } else {
        showError('Selected location is outside Manila');
      }
    } catch (e) {
      showError('Error finding location');
    }
  }

  void useCurrentLocation() async {
    if (currentLocation == null) {
      showError('Current location not available');
      return;
    }

    try {
      final address = await GeocodingService.getAddressFromLocation(currentLocation!);
      
      if (currentSearchMode == 'origin') {
        originController.text = address;
        originPin = currentLocation;
        showOriginSheet = false;
      } else {
        destinationController.text = address;
        destinationPin = currentLocation;
        showDestinationSheet = false;
      }
      _safeSetState();
    } catch (e) {
      if (currentSearchMode == 'origin') {
        originController.text = 'Current Location';
        originPin = currentLocation;
        showOriginSheet = false;
      } else {
        destinationController.text = 'Current Location';
        destinationPin = currentLocation;
        showDestinationSheet = false;
      }
      _safeSetState();
    }
  }

  void pinOnMap() {
    if (currentSearchMode == 'origin') {
      isSelectingOrigin = true;
      showOriginSheet = false;
    } else {
      isSelectingDestination = true;
      showDestinationSheet = false;
    }
    _safeSetState();
    showError('Tap on the map to pin your ${currentSearchMode}');
  }

  void closeSearchSheet() {
    showOriginSheet = false;
    showDestinationSheet = false;
    _safeSetState();
  }

  // Method to mark controller as disposed
  void dispose() {
    _mounted = false;
    originController.dispose();
    destinationController.dispose();
  }

  // Test connection method for debugging
  Future<void> testBackendConnection() async {
    print("🧪 Testing backend connection...");
    try {
      final isHealthy = await RoutingService.checkHealth();
      print("🧪 Health check result: $isHealthy");
      
      if (isHealthy) {
        showSuccess("Backend connection successful!");
      } else {
        showError("Backend health check failed");
      }
    } catch (e) {
      print("🧪 Connection test error: $e");
      showError("Connection test failed: $e");
    }
  }
}