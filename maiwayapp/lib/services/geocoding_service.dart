import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maiwayapp/services/routing_service.dart';

class GeocodingService {
  /// Get address from coordinates (reverse geocoding via backend Google Geocoding API).
  static Future<String> getAddressFromLocation(LatLng location) async {
    try {
      final url = Uri.parse(
        '${RoutingService.baseUrl}/places/reverse?lat=${location.latitude}&lng=${location.longitude}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        final address = data?['address']?.toString();
        if (address != null && address.isNotEmpty) return address;
      }
    } catch (_) {}
    return 'Current location';
  }

  /// Get coordinates from address (forward geocoding). Use search + place_id flow for now.
  static Future<LatLng?> getLocationFromAddress(String address) async {
    return null;
  }

  /// Google Places Autocomplete via backend (requires GOOGLE_MAPS_API_KEY in backend .env).
  /// Returns list of { description, place_id }.
  static Future<List<Map<String, dynamic>>> searchGooglePlaces(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        '${RoutingService.baseUrl}/places/autocomplete?q=${Uri.encodeComponent(query.trim())}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>?;
      final predictions = data?['predictions'] as List?;
      if (predictions == null) return [];
      return predictions
          .where(
            (e) =>
                e is Map &&
                e['place_id'] != null &&
                (e['description'] ?? '').toString().isNotEmpty,
          )
          .map(
            (e) => {
              'description': (e['description'] ?? '').toString(),
              'place_id': (e['place_id'] ?? '').toString(),
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Resolve Google place_id to lat/lng and address via backend.
  static Future<Map<String, dynamic>?> getLocationFromPlaceId(
    String placeId,
  ) async {
    if (placeId.isEmpty) return null;
    try {
      final url = Uri.parse(
        '${RoutingService.baseUrl}/places/details?place_id=${Uri.encodeComponent(placeId)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>?;
      if (data == null) return null;
      final lat = data['lat'];
      final lng = data['lng'];
      if (lat == null || lng == null) return null;
      return {
        'lat': (lat is num) ? lat.toDouble() : double.tryParse(lat.toString()),
        'lng': (lng is num) ? lng.toDouble() : double.tryParse(lng.toString()),
        'formatted_address': (data['formatted_address'] ?? '').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Fallback place search when Google returns nothing (e.g. no backend key). Returns empty.
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    return [];
  }

  static List<Map<String, dynamic>> _landmarks = [];
  static bool _landmarksLoaded = false;

  static Future<void> _loadLandmarks() async {
    if (_landmarksLoaded) return;
    try {
      final data = await rootBundle.loadString('assets/landmarks.geojson');
      final geojson = json.decode(data);
      if (geojson is Map && geojson['features'] is List) {
        _landmarks =
            (geojson['features'] as List).map<Map<String, dynamic>>((feature) {
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

  static Future<List<Map<String, dynamic>>> searchLandmarks(
    String query,
  ) async {
    await _loadLandmarks();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _landmarks.where((landmark) {
      final name = (landmark['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  /// Check if a location is over water. No external API; returns false (allow pin).
  static Future<bool> isWaterOrNearWater(
    LatLng location, {
    double thresholdMeters = 20,
  }) async {
    return false;
  }
}
