import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// RoutingService handles all backend API calls for routing, stop search, and health checks.
/// It expects the backend to return route responses with keys: segments, shapes, summary, fare_breakdown.
class RoutingService {
  /// Backend URL. On web we use localhost so the browser can reach Flask on the same machine
  /// (avoids Windows Firewall blocking 192.168.x.x:5000). For mobile/emulator use your PC's LAN IP.
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:5000' : 'http://192.168.10.192:5000';

  /// RFR (fare prediction) backend URL. Runs on port 5002 when using py main.py locally.
  /// Same host as baseUrl, different port. Use this for /predict_fare so the survey connects locally.
  static String get rfrBaseUrl =>
      kIsWeb ? 'http://localhost:5002' : 'http://192.168.10.192:5002';

  // Health check with timeout
  static Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      print('🧪 Health check URL: $url');

      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      print('🧪 Health check status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('🧪 Health check failed: $e');
      return false;
    }
  }

  // Get route from backend with improved error handling
  /// Request a route from the backend. Expects backend to return a JSON with keys:
  /// - fastest/cheapest/convenient: List of segments
  /// - shapes: List of [lon, lat] coordinates
  /// - summary: Map with total_cost, total_distance, etc.
  /// - fare_breakdown: Map of mode to fare
  ///
  /// Uses Google Directions API (transit) + MaiWay inference layer. No local routing engine.
  /// Requires GOOGLE_MAPS_API_KEY on the backend.
  static Future<Map<String, dynamic>?> getRoute({
    required LatLng startLocation,
    required LatLng endLocation,
    required String mode,
    required List<String> modes,
    String passengerType = 'regular',
    List<String> preferences = const ['fastest', 'cheapest', 'convenient'],
    bool useGoogle = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/route');
      print('[ROUTE] URL: $url (useGoogle: $useGoogle)');
      final requestBody = {
        'start': {
          'lat': startLocation.latitude,
          'lon': startLocation.longitude,
        },
        'end': {'lat': endLocation.latitude, 'lon': endLocation.longitude},
        'mode': mode,
        'modes': modes,
        'passenger_type': passengerType,
        'preferences': preferences,
        if (useGoogle) 'use_google': true,
      };
      print('[ROUTE] REQUEST BODY: ' + json.encode(requestBody));
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 120)); // increased to 120s to avoid frontend timeout
      print('[ROUTE] RESPONSE: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Check for backend error
        if (data.containsKey('error')) {
          return {
            'error': data['error'],
            'type': 'backend_error',
            'details': data,
          };
        }
        // Only check for the requested mode key and summary
        if (!data.containsKey(mode) || !data.containsKey('summary')) {
          return {
            'error': 'Incomplete route data from backend',
            'type': 'incomplete_response',
            'details': data,
          };
        }
        return data;
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        return {
          'error': errorData['error'] ?? 'Invalid request',
          'type': 'bad_request',
        };
      } else if (response.statusCode == 500) {
        return {
          'error': 'Server error occurred while processing route',
          'type': 'server_error',
          'details': response.body,
        };
      } else {
        return {
          'error':
              'Server returned ${response.statusCode}: ${response.reasonPhrase}',
          'type': 'http_error',
          'details': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('[ROUTE] ClientException: $e');
      return {
        'error':
            'Cannot connect to server. Check your network connection and ensure the Flask server is running.',
        'type': 'connection_error',
        'details': e.toString(),
      };
    } on FormatException catch (e) {
      print('[ROUTE] FormatException: $e');
      return {
        'error': 'Invalid response format from server',
        'type': 'parse_error',
        'details': e.toString(),
      };
    } catch (e) {
      print('[ROUTE] Unexpected error: $e');
      return {
        'error': 'Unexpected error: ${e.toString()}',
        'type': 'unknown_error',
        'details': e.toString(),
      };
    }
  }

  // Search for stops/places with improved error handling
  static Future<List<Map<String, dynamic>>> searchStops(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final url = Uri.parse(
        '$baseUrl/search-stops?q=${Uri.encodeComponent(query.trim())}',
      );
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('suggestions')) {
          return List<Map<String, dynamic>>.from(data['suggestions']);
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Test connection method for debugging
  static Future<void> testConnection() async {
    print("🧪 Testing connection to: $baseUrl");
    try {
      // Test basic connectivity
      print("🧪 Testing health endpoint...");
      final healthResponse = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      print(
        "🧪 Health check response: ${healthResponse.statusCode} - ${healthResponse.body}",
      );

      // Test index endpoint
      print("🧪 Testing index endpoint...");
      final indexResponse = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 10));

      print(
        "🧪 Index response: ${indexResponse.statusCode} - ${indexResponse.body}",
      );
    } catch (e) {
      print("🧪 Connection test failed: $e");
      print("🧪 Error type: ${e.runtimeType}");
    }
  }
}
