import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// RoutingService handles all backend API calls for routing, stop search, and health checks.
/// It expects the backend to return route responses with keys: segments, shapes, summary, fare_breakdown.
class RoutingService {
  // QUICK FIX: Using static URL to ensure consistent IP address
  static const String baseUrl =
      'https://maiway-backend-production.up.railway.app/routing'; // Your IP address

  // ALTERNATIVE IP: If the above doesn't work, try this one:
  // static const String baseUrl = 'http://192.168.225.1:5000'; // Alternative IP

  // Alternative: Dynamic URL detection (commented out for now)
  // static String get baseUrl {
  //   // Check if running on web first
  //   if (kIsWeb) {
  //     return 'http://localhost:5000';
  //   }
  //
  //   // For mobile platforms, use your computer's IP address
  //   return 'http://172.20.96.139:5000'; // Your computer's IP address
  // }

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
  static Future<Map<String, dynamic>?> getRoute({
    required LatLng startLocation,
    required LatLng endLocation,
    required String mode,
    required List<String> modes,
    String passengerType = 'regular',
    List<String> preferences = const ['fastest', 'cheapest', 'convenient'],
  }) async {
    try {
      final url = Uri.parse('$baseUrl/route');
      print('[ROUTE] URL: $url');
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
          .timeout(const Duration(seconds: 45)); // Increased timeout
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
