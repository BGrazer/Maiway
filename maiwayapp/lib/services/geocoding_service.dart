import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

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
      print('🚨 Mapbox reverse geocoding error: $e');
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
      print('🚨 Mapbox place search error: $e');
      return [];
    }
  }
}