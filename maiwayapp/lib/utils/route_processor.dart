import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';

class RouteProcessor {
  /// Process route response from routing service
  static Map<String, dynamic> processRouteResponse(Map<String, dynamic>? response) {
    print('🟦 processRouteResponse input: ' + response.toString());
    if (response == null) {
      print('❌ processRouteResponse: response is null');
      return {
        'success': false,
        'error': 'No response from routing service',
      };
    }

    if (response.containsKey('error')) {
      print('❌ processRouteResponse: error in response: ' + response['error'].toString());
      return {
        'success': false,
        'error': _formatErrorMessage(response),
      };
    }

    // Handle new backend format: {"fastest": [...], "cheapest": [...], "convenient": [...], "shapes": [...], "summary": {...}}
    final modeKeys = ['fastest', 'cheapest', 'convenient'];
    String? foundModeKey;
    List? routeSegments;
    
    // Find which mode key contains the route data
    for (final modeKey in modeKeys) {
      if (response.containsKey(modeKey) && response[modeKey] is List) {
        foundModeKey = modeKey;
        routeSegments = response[modeKey] as List;
        break;
      }
    }

    if (foundModeKey != null && routeSegments != null && response.containsKey('shapes')) {
      final shapes = response['shapes'] as List?;
      final summary = response['summary'] as Map<String, dynamic>?;

      print('🟩 processRouteResponse: found mode key: $foundModeKey');
      print('🟩 processRouteResponse: routeSegments=' + routeSegments.toString());
      print('🟩 processRouteResponse: shapes=' + shapes.toString());
      print('🟩 processRouteResponse: summary=' + summary.toString());

      if (routeSegments.isEmpty) {
        print('❌ processRouteResponse: No route segments found');
        return {
          'success': false,
          'error': 'No route segments found in response',
        };
      }

      if (shapes == null || shapes.isEmpty) {
        print('❌ processRouteResponse: No route shapes found');
        return {
          'success': false,
          'error': 'No route shapes found in response',
        };
      }

      // Process route segments into RouteSegment objects
      final List<RouteSegment> segments = _processRouteSegments(routeSegments);
      
      // Process shapes into polyline points (new format: direct coordinate arrays)
      List<LatLng> polylinePoints = [];
      if (shapes != null && shapes.isNotEmpty) {
        polylinePoints = _processNewShapeFormat(shapes);
      } else {
        // If no shapes provided, create a simple polyline from route segments
        polylinePoints = _createPolylineFromSegments(segments);
      }
      
      print('🟩 processRouteResponse: parsed segments=' + segments.toString());
      print('🟩 processRouteResponse: parsed polylinePoints=' + polylinePoints.toString());

      // Allow routes with empty polylines (e.g., walking-only routes)
      if (polylinePoints.isEmpty && segments.isNotEmpty) {
        // Create a simple straight line polyline for walking routes
        polylinePoints = _createSimplePolyline(routeSegments);
      }

      // Extract stops from route segments
      final List<Map<String, dynamic>> stops = _extractStopsFromRoute(routeSegments);

      // Process fare breakdown
      final Map<String, double> fareBreakdown = _processFareBreakdown(summary);

      return {
        'success': true,
        'routeData': {
          'shapes': shapes,
          'stops': stops,
          'segments': segments,
          'total_cost': summary?['total_cost'] ?? 0,
          'total_distance': summary?['total_distance'] ?? 0,
          'route_segments': routeSegments,
          'fare_breakdown': fareBreakdown,
        },
        'polylinePoints': polylinePoints,
        'segments': segments,
        'stops': stops,
        'totalCost': summary?['total_cost']?.toDouble() ?? 0.0,
        'totalDistance': summary?['total_distance']?.toDouble() ?? 0.0,
        'fareBreakdown': fareBreakdown,
        'summary': summary,
      };
    }

    // Handle old response format (fallback)
    // Old format: {"success": true, "route": {"shapes": [...], "stops": [...]}}
    if (!response.containsKey('success') || response['success'] != true) {
      return {
        'success': false,
        'error': 'Invalid response format from routing service',
      };
    }

    final routeData = response['route'];
    if (routeData == null) {
      return {
        'success': false,
        'error': 'No route data received',
      };
    }

    // Extract and validate route components (old format)
    final shapes = routeData['shapes'] as List?;
    final stops = routeData['stops'] as List?;
    final totalCost = routeData['total_cost'];

    if (shapes == null || shapes.isEmpty) {
      return {
        'success': false,
        'error': 'No route shapes found in response',
      };
    }

    // Process shapes into polyline points (old format)
    final List<LatLng> polylinePoints = _processOldShapeFormat(shapes);
    
    if (polylinePoints.isEmpty) {
      return {
        'success': false,
        'error': 'No valid coordinates found in route shapes',
      };
    }

    return {
      'success': true,
      'routeData': routeData,
      'polylinePoints': polylinePoints,
      'stops': List<Map<String, dynamic>>.from(stops ?? []),
      'totalCost': totalCost?.toDouble(),
    };
  }

  /// Process route segments into RouteSegment objects
  static List<RouteSegment> _processRouteSegments(List routeSegments) {
    final List<RouteSegment> segments = [];
    
    for (final segment in routeSegments) {
      if (segment is Map<String, dynamic>) {
        try {
          segments.add(RouteSegment.fromMap(segment));
        } catch (e) {
          // Skip invalid segments silently
          continue;
        }
      }
    }
    
    return segments;
  }

  /// Process fare breakdown from summary
  static Map<String, double> _processFareBreakdown(Map<String, dynamic>? summary) {
    final Map<String, double> breakdown = {};
    
    if (summary != null && summary.containsKey('fare_breakdown')) {
      final fareData = summary['fare_breakdown'];
      if (fareData is Map) {
        fareData.forEach((key, value) {
          if (value is num) {
            breakdown[key.toString()] = value.toDouble();
          }
        });
      }
    }
    
    return breakdown;
  }

  /// Extract stops from route segments (new format)
  static List<Map<String, dynamic>> _extractStopsFromRoute(List routeSegments) {
    final List<Map<String, dynamic>> stops = [];
    final Set<String> addedStopIds = {}; // Avoid duplicates

    for (final segment in routeSegments) {
      if (segment is Map<String, dynamic>) {
        // Add from_stop
        final fromStop = segment['from_stop'];
        if (fromStop is Map<String, dynamic> && fromStop.containsKey('id')) {
          final stopId = fromStop['id'].toString();
          if (!addedStopIds.contains(stopId)) {
            stops.add(Map<String, dynamic>.from(fromStop));
            addedStopIds.add(stopId);
          }
        }

        // Add to_stop
        final toStop = segment['to_stop'];
        if (toStop is Map<String, dynamic> && toStop.containsKey('id')) {
          final stopId = toStop['id'].toString();
          if (!addedStopIds.contains(stopId)) {
            stops.add(Map<String, dynamic>.from(toStop));
            addedStopIds.add(stopId);
          }
        }
      }
    }

    return stops;
  }

  /// Process new shape format: direct coordinate arrays [[lng, lat], [lng, lat], ...]
  static List<LatLng> _processNewShapeFormat(List shapes) {
    final List<LatLng> allPoints = [];
    
    for (final coord in shapes) {
      if (coord != null && coord is List && coord.length >= 2) {
        try {
          double lon = (coord[0] as num).toDouble();
          double lat = (coord[1] as num).toDouble();
          allPoints.add(LatLng(lat, lon));
        } catch (e) {
          // Skip invalid coordinates silently
          continue;
        }
      }
    }
    
    return allPoints;
  }

  /// Process old shape format: [{"coordinates": [[lng, lat], ...]}, ...]
  static List<LatLng> _processOldShapeFormat(List shapes) {
    final List<LatLng> allPoints = [];
    
    for (final shape in shapes) {
      if (shape != null && shape.containsKey('coordinates')) {
        final coordinates = shape['coordinates'] as List? ?? [];
        if (coordinates != null) {
          for (final coord in coordinates) {
            if (coord != null && coord is List && coord.length >= 2) {
              try {
                double lon = (coord[0] as num).toDouble();
                double lat = (coord[1] as num).toDouble();
                allPoints.add(LatLng(lat, lon));
              } catch (e) {
                print("⚠️ Invalid coordinate in old format: $coord");
              }
            }
          }
        }
      }
    }
    
    return allPoints;
  }

  /// Format error message with suggestions if available
  static String _formatErrorMessage(Map<String, dynamic> response) {
    String errorMsg = response['error'] ?? 'Unknown error occurred';
    
    // Handle specific error types
    if (response.containsKey('type')) {
      String errorType = response['type'];
      if (errorType == 'start_not_found' || errorType == 'end_not_found') {
        List<dynamic> suggestions = response['suggestions'] ?? [];
        if (suggestions.isNotEmpty) {
          errorMsg += '\n\nSuggestions:';
          for (var suggestion in suggestions.take(3)) {
            errorMsg += '\n• ${suggestion['stop_name']}';
          }
        }
      }
    }
    
    return errorMsg;
  }

  /// Validate route data structure
  static bool isValidRouteData(Map<String, dynamic> routeData) {
    return routeData.containsKey('shapes') &&
           routeData['shapes'] is List &&
           (routeData['shapes'] as List).isNotEmpty;
  }

  /// Extract route summary information
  static Map<String, dynamic> getRouteSummary(Map<String, dynamic> routeData) {
    final shapes = routeData['shapes'] as List? ?? [];
    final stops = routeData['stops'] as List? ?? [];
    final segments = routeData['segments'] as List<RouteSegment>? ?? [];
    final totalCost = routeData['total_cost'];
    final totalDistance = routeData['total_distance'];
    final fareBreakdown = routeData['fare_breakdown'] as Map<String, double>? ?? {};
    
    int totalPoints = 0;
    if (shapes.isNotEmpty && shapes.first is List) {
      // New format: direct coordinate arrays
      totalPoints = shapes.length;
    } else {
      // Old format: shape objects with coordinates
      for (final shape in shapes) {
        if (shape != null && shape.containsKey('coordinates')) {
          final coordinates = shape['coordinates'] as List? ?? [];
          totalPoints += coordinates.length;
        }
      }
    }
    
    return {
      'totalCost': totalCost?.toDouble(),
      'totalDistance': totalDistance?.toDouble(),
      'totalStops': stops.length,
      'totalSegments': segments.length,
      'totalPoints': totalPoints,
      'fareBreakdown': fareBreakdown,
      'hasValidRoute': totalPoints > 0,
    };
  }

  /// Get all coordinates from route segments for polyline rendering
  static List<LatLng> getSegmentCoordinates(List<RouteSegment> segments) {
    final List<LatLng> allCoordinates = [];
    
    for (final segment in segments) {
      allCoordinates.addAll(segment.coordinates);
    }
    
    return allCoordinates;
  }

  /// Create polyline from route segments when shapes are not available
  static List<LatLng> _createPolylineFromSegments(List<RouteSegment> segments) {
    final List<LatLng> allPoints = [];
    
    for (final segment in segments) {
      if (segment.coordinates.isNotEmpty) {
        allPoints.addAll(segment.coordinates);
      }
    }
    
    return allPoints;
  }

  /// Create a simple polyline for routes without detailed shapes
  static List<LatLng> _createSimplePolyline(List routeSegments) {
    final List<LatLng> points = [];
    
    for (final segment in routeSegments) {
      if (segment is Map<String, dynamic>) {
        // Try to get coordinates from shape if available
        if (segment.containsKey('shape') && segment['shape'] is List) {
          final shape = segment['shape'] as List;
          for (final coord in shape) {
            if (coord is List && coord.length >= 2) {
              try {
                double lon = (coord[0] as num).toDouble();
                double lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
    }
    
    // If no valid points found, create a simple straight line
    if (points.isEmpty && routeSegments.isNotEmpty) {
      final firstSegment = routeSegments.first;
      final lastSegment = routeSegments.last;
      
      if (firstSegment is Map<String, dynamic> && lastSegment is Map<String, dynamic>) {
        // Try to get coordinates from from_stop and to_stop
        final fromStop = firstSegment['from_stop'];
        final toStop = lastSegment['to_stop'];
        
        if (fromStop is Map<String, dynamic> && toStop is Map<String, dynamic>) {
          final fromCoords = fromStop['coordinates'] as List?;
          final toCoords = toStop['coordinates'] as List?;
          
          if (fromCoords != null && fromCoords.length >= 2 && 
              toCoords != null && toCoords.length >= 2) {
            try {
              final fromLat = (fromCoords[1] as num).toDouble();
              final fromLon = (fromCoords[0] as num).toDouble();
              final toLat = (toCoords[1] as num).toDouble();
              final toLon = (toCoords[0] as num).toDouble();
              
              points.add(LatLng(fromLat, fromLon));
              points.add(LatLng(toLat, toLon));
            } catch (e) {
              print('🟥 Error creating simple polyline: $e');
            }
          }
        }
      }
    }
    
    return points;
  }
}