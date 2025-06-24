import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart'; // Add this import

class RoutingService {
  // Fixed base URL detection
  static String get baseUrl {
    // Check if running on web first
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    // For mobile platforms, use safe fallback
    try {
      // Try to use platform detection with fallback
      return 'http://localhost:5000'; // Safe default
    } catch (e) {
      // If platform detection fails, use localhost
      return 'http://localhost:5000';
    }
  }

  // Alternative: Use a simple static URL to test
  // static const String baseUrl = 'http://localhost:5000';
  
  // Health check with timeout
  static Future<bool> checkHealth() async {
    try {
      print("🏥 Checking health at: $baseUrl/health");
      
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print("🏥 Health check response: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("✅ Backend is healthy: ${response.body}");
        return true;
      } else {
        print("❌ Backend unhealthy: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Health check failed: $e");
      return false;
    }
  }
  
  // Get route from backend with improved error handling
  static Future<Map<String, dynamic>?> getRoute({
    required LatLng startLocation,
    required LatLng endLocation,
    required String mode,
    required List<String> modes,
  }) async {
    try {
      // First check if backend is healthy
      final isHealthy = await checkHealth();
      if (!isHealthy) {
        return {
          'error': 'Backend server is not responding. Please check if the Flask server is running.',
          'type': 'server_unreachable',
        };
      }

      final url = Uri.parse('$baseUrl/route');
      
      final requestBody = {
        'start_location': {
          'lat': startLocation.latitude,
          'lng': startLocation.longitude,
        },
        'end_location': {
          'lat': endLocation.latitude,
          'lng': endLocation.longitude,
        },
        'mode': mode,
        'modes': modes,
      };

      print("🚀 Sending route request to: $url");
      print("📤 Request payload: ${json.encode(requestBody)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30)); // Add timeout

      print("📡 Response status: ${response.statusCode}");
      print("📄 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 400) {
        // Bad request - likely invalid input
        final errorData = json.decode(response.body);
        return {
          'error': errorData['error'] ?? 'Invalid request',
          'type': 'bad_request',
        };
      } else if (response.statusCode == 500) {
        // Server error
        return {
          'error': 'Server error occurred while processing route',
          'type': 'server_error',
          'details': response.body,
        };
      } else {
        print("❌ HTTP Error ${response.statusCode}: ${response.body}");
        return {
          'error': 'Server returned ${response.statusCode}: ${response.reasonPhrase}',
          'type': 'http_error',
          'details': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print("❌ HTTP Client error: $e");
      return {
        'error': 'Cannot connect to server. Check your network connection and ensure the Flask server is running.',
        'type': 'connection_error',
      };
    } on FormatException catch (e) {
      print("❌ JSON parsing error: $e");
      return {
        'error': 'Invalid response format from server',
        'type': 'parse_error',
      };
    } catch (e) {
      print("❌ Unexpected error: $e");
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
      print("🔍 Searching stops: $url");
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print("🔍 Search response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('suggestions')) {
          return List<Map<String, dynamic>>.from(data['suggestions']);
        }
        return [];
      } else {
        print("❌ Search error ${response.statusCode}: ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Search network error: $e");
      return [];
    }
  }

  // Test connection method for debugging
  static Future<void> testConnection() async {
    print("🧪 Testing connection to: $baseUrl");
    
    try {
      // Test basic connectivity
      final healthResponse = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      print("🧪 Health test: ${healthResponse.statusCode}");
      print("🧪 Health body: ${healthResponse.body}");
      
      // Test index endpoint
      final indexResponse = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(const Duration(seconds: 5));
      
      print("🧪 Index test: ${indexResponse.statusCode}");
      print("🧪 Index body: ${indexResponse.body}");
      
    } catch (e) {
      print("🧪 Connection test failed: $e");
    }
  }
}