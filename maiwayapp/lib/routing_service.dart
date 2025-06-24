import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class RoutingService {
  // Fixed base URL detection
  static String get baseUrl {
    // Check if running on web first
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    // For mobile platforms, use safe fallback
    try {
      return 'http://localhost:5000'; // Safe default
    } catch (e) {
      return 'http://localhost:5000';
    }
  }

  // Alternative: Use a simple static URL to test
  // static const String baseUrl = 'http://localhost:5000';
  
  // Health check with timeout
  static Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Get route from backend with improved error handling
  static Future<Map<String, dynamic>?> getRoute({
    required LatLng startLocation,
    required LatLng endLocation,
    required String mode,
    required List<String> modes,
    String passengerType = 'regular',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/route');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'start': {
            'lat': startLocation.latitude,
            'lon': startLocation.longitude,
          },
          'end': {
            'lat': endLocation.latitude,
            'lon': endLocation.longitude,
          },
          'mode': mode,
          'modes': modes,
          'passenger_type': passengerType,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
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
          'error': 'Server returned ${response.statusCode}: ${response.reasonPhrase}',
          'type': 'http_error',
          'details': response.body,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'error': 'Cannot connect to server. Check your network connection and ensure the Flask server is running.',
        'type': 'connection_error',
      };
    } on FormatException catch (e) {
      return {
        'error': 'Invalid response format from server',
        'type': 'parse_error',
      };
    } catch (e) {
      return {
        'error': 'Unexpected error: ${e.toString()}',
        'type': 'unknown_error',
      };
    }
  }

  // Search for stops/places with improved error handling
  static Future<List<Map<String, dynamic>>> searchStops(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      
      final url = Uri.parse('$baseUrl/search-stops?q=${Uri.encodeComponent(query.trim())}');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

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
    try {
      // Test basic connectivity
      final healthResponse = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      // Test index endpoint
      final indexResponse = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(const Duration(seconds: 5));
      
    } catch (e) {
      print("🧪 Connection test failed: $e");
    }
  }
}