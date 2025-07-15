import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class GeocodingService {
  /// Get address from coordinates (reverse geocoding)
  /// (Optional: implement with Mapbox if needed, or leave as is for now)
  static Future<String> getAddressFromLocation(LatLng location) async {
    const String mapboxToken = 'pk.eyJ1IjoibWFpd2F5YWRtaW4iLCJhIjoiY21jOG5tdDY1MWZrcTJrcHl4c2lrZTJuaSJ9.fEoTCb7zqrsJuCLOjcabXg';
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json?access_token=$mapboxToken&limit=1&country=PH';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          return features[0]['place_name'] ?? 'Unknown location';
        }
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  /// Get coordinates from address (forward geocoding)
  /// (Optional: implement with Mapbox if needed, or leave as is for now)
  static Future<LatLng?> getLocationFromAddress(String address) async {
    // TODO: Replace with Mapbox forward geocoding if needed
    return null;
  }

  /// Search for places matching a query using Mapbox
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    const String mapboxToken = 'pk.eyJ1IjoibWFpd2F5YWRtaW4iLCJhIjoiY21jOG5tdDY1MWZrcTJrcHl4c2lrZTJuaSJ9.fEoTCb7zqrsJuCLOjcabXg';
    // Manila bounding box: 120.95,14.55,121.02,14.65
    // Proximity: 120.9842,14.5995 (center of Manila)
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$mapboxToken&autocomplete=true&limit=8&country=PH&bbox=120.95,14.55,121.02,14.65&proximity=120.9842,14.5995';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        // Only return features with a valid place_name
        return features.where((feature) => feature['place_name'] != null && feature['place_name'].toString().trim().isNotEmpty).map((feature) => {
          'name': feature['place_name'],
          'latitude': (feature['center'] as List)[1] ?? 0.0,
          'longitude': (feature['center'] as List)[0] ?? 0.0,
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _landmarks = [];
  static bool _landmarksLoaded = false;

  static Future<void> _loadLandmarks() async {
    if (_landmarksLoaded) return;
    try {
      final data = await rootBundle.loadString('assets/landmarks.geojson');
      final geojson = json.decode(data);
      if (geojson is Map && geojson['features'] is List) {
        _landmarks = (geojson['features'] as List).map<Map<String, dynamic>>((feature) {
          final props = feature['properties'] ?? {};
          final geom = feature['geometry'] ?? {};
          final coords = geom['coordinates'] ?? [0.0, 0.0];
          return {
            'name': props['name'] ?? '',
            'latitude': coords[1],
            'longitude': coords[0],
          };
        }).toList();
      }
      _landmarksLoaded = true;
    } catch (e) {
      _landmarks = [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchLandmarks(String query) async {
    await _loadLandmarks();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _landmarks.where((landmark) {
      final name = (landmark['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  /// Check if a location is over water or within [thresholdMeters] of a water body
  static Future<bool> isWaterOrNearWater(LatLng location, {double thresholdMeters = 20}) async {
    const String mapboxToken = 'pk.eyJ1IjoibWFpd2F5YWRtaW4iLCJhIjoiY21jOG5tdDY1MWZrcTJrcHl4c2lrZTJuaSJ9.fEoTCb7zqrsJuCLOjcabXg';
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json?types=water&access_token=$mapboxToken&limit=1';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final feature = features[0] as Map<String, dynamic>;
          final distance = (feature['distance'] ?? thresholdMeters + 1) as num;
          return distance <= thresholdMeters;
        }
      }
    } catch (_) {}
    return false;
  }
}