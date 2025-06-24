import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class GeocodingService {
  static const String _mapboxToken = 'pk.eyJ1IjoibWFpd2F5YWRtaW4iLCJhIjoiY21jOG5tdDY1MWZrcTJrcHl4c2lrZTJuaSJ9.fEoTCb7zqrsJuCLOjcabXg';

  /// Get address from coordinates (reverse geocoding) using Mapbox
  static Future<String> getAddressFromLocation(LatLng location) async {
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json?access_token=$_mapboxToken&limit=1&country=PH';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          return features[0]['place_name'] ?? 'Unknown location';
        }
        return 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      print('🚨 Mapbox reverse geocoding error: $e');
      return 'Unknown location';
    }
  }

  /// Get coordinates from address (forward geocoding) using Mapbox
  static Future<LatLng?> getLocationFromAddress(String address) async {
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(address)}.json?access_token=$_mapboxToken&limit=1&country=PH';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final center = features[0]['center'] as List;
          return LatLng(center[1], center[0]);
        }
        return null;
      }
      return null;
    } catch (e) {
      print('🚨 Mapbox forward geocoding error: $e');
      return null;
    }
  }

  /// Search for places matching a query using Mapbox
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_mapboxToken&autocomplete=true&limit=5&country=PH';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        return features.map((feature) => {
          'name': feature['place_name'] ?? 'Unknown',
          'latitude': (feature['center'] as List)[1] ?? 0.0,
          'longitude': (feature['center'] as List)[0] ?? 0.0,
        }).toList();
      }
      return [];
    } catch (e) {
      print('🚨 Mapbox place search error: $e');
      return [];
    }
  }
}