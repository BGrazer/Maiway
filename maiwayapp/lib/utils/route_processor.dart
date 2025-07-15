import 'package:latlong2/latlong.dart';
import '../models/route_segment.dart';
import 'package:maiwayapp/models/transport_mode.dart';
import 'package:maiwayapp/utils/polyline_utils.dart';

/// RouteProcessor parses backend route responses and converts them to frontend data structures.
class RouteProcessor {
  /// Process route response from routing service
    /// Processes the backend route response and extracts segments, shapes, summary, fare breakdown.
  /// Handles both new and legacy response formats.
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

    // Handle new backend format: {"fastest": [...], "cheapest": [...], "convenient": [...], "summary": {...}}
    final modeKeys = ['fastest', 'cheapest', 'convenient'];
    String? foundModeKey;
    List? routeSegments;
    for (final modeKey in modeKeys) {
      if (response.containsKey(modeKey) && response[modeKey] is List) {
        foundModeKey = modeKey;
        routeSegments = response[modeKey] as List;
        break;
      }
    }

    if (foundModeKey != null && routeSegments != null) {
      final summary = response['summary'] as Map<String, dynamic>?;

      print('🟩 processRouteResponse: found mode key: $foundModeKey');
      print('🟩 processRouteResponse: routeSegments=' + routeSegments.toString());
      print('🟩 processRouteResponse: summary=' + summary.toString());

      if (routeSegments.isEmpty) {
        print('❌ processRouteResponse: No route segments found');
        return {
          'success': false,
          'error': 'No route segments found in response',
        };
      }

      // Process route segments into RouteSegment objects
      final List<RouteSegment> segments = _processRouteSegments(routeSegments);

      // Aggregate all segment polylines into a single polyline for the route
      List<LatLng> polylinePoints = [];
      for (final segment in segments) {
        polylinePoints.addAll(segment.polyline);
      }

      // Debug: Print each segment's polyline and coordinates if available
      for (int i = 0; i < segments.length; i++) {
        print('[DEBUG] Segment $i: ${segments[i].toString()}');
        if (segments[i].polyline.isNotEmpty) {
          print('[DEBUG] Segment $i polyline: ${segments[i].polyline}');
        }
        if (segments[i].coordinates.isNotEmpty) {
          print('[DEBUG] Segment $i coordinates: ${segments[i].coordinates}');
        }
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
          'segments': segments,
          'stops': stops,
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

    // Legacy/old format support (deprecated)
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
    /// Converts a list of segment maps from backend to RouteSegment objects.
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
    
    print('🟦 _processNewShapeFormat: input shapes length = ${shapes.length}');
    print('🟦 _processNewShapeFormat: shapes type = ${shapes.runtimeType}');
    if (shapes.isNotEmpty) {
      print('🟦 _processNewShapeFormat: first shape type = ${shapes.first.runtimeType}');
      print('🟦 _processNewShapeFormat: first shape length = ${shapes.first is List ? (shapes.first as List).length : 'N/A'}');
    }
    
    // Handle the case where shapes is a list of coordinate arrays
    // Each shape is an array of coordinates: [[lng, lat], [lng, lat], ...]
    for (int i = 0; i < shapes.length; i++) {
      final shape = shapes[i];
      if (shape != null && shape is List) {
        print('🟦 _processNewShapeFormat: processing shape with ${shape.length} coordinates');
        
        List<LatLng> shapePoints = PolylineUtils.parsePolyline(shape);
        
        // For the first shape, add all points
        if (i == 0) {
          allPoints.addAll(shapePoints);
        } else {
          // For subsequent shapes, check if the first point matches the last point of previous shape
          if (shapePoints.isNotEmpty && allPoints.isNotEmpty) {
            final firstPoint = shapePoints.first;
            final lastPoint = allPoints.last;
            
            // If points are very close (within 1 meter), skip the first point
            if ((firstPoint.latitude - lastPoint.latitude).abs() < 0.00001 && 
                (firstPoint.longitude - lastPoint.longitude).abs() < 0.00001) {
              allPoints.addAll(shapePoints.skip(1));
            } else {
              allPoints.addAll(shapePoints);
            }
          } else {
            allPoints.addAll(shapePoints);
          }
        }
      }
    }
    
    print('🟦 _processNewShapeFormat: extracted ${allPoints.length} points');
    return allPoints;
  }

  /// Process old shape format: [{"coordinates": [[lng, lat], ...]}, ...]
  static List<LatLng> _processOldShapeFormat(List shapes) {
    final List<LatLng> allPoints = [];
    
    for (final shape in shapes) {
      if (shape != null && shape.containsKey('coordinates')) {
        final coordinates = shape['coordinates'] as List? ?? [];
        if (coordinates != null) {
          final parsedCoords = PolylineUtils.parsePolyline(coordinates);
          allPoints.addAll(parsedCoords);
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
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.coordinates.isNotEmpty) {
        if (i == 0) {
          // For the first segment, add all points
          allPoints.addAll(segment.coordinates);
        } else {
          // For subsequent segments, check if the first point matches the last point of previous segment
          final firstPoint = segment.coordinates.first;
          final lastPoint = allPoints.last;
          
          // If points are very close (within 1 meter), skip the first point
          if ((firstPoint.latitude - lastPoint.latitude).abs() < 0.00001 && 
              (firstPoint.longitude - lastPoint.longitude).abs() < 0.00001) {
            allPoints.addAll(segment.coordinates.skip(1));
          } else {
            allPoints.addAll(segment.coordinates);
          }
        }
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
          final parsedShape = PolylineUtils.parsePolyline(shape);
          points.addAll(parsedShape);
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

  /// Create a clean polyline from shapes without duplicate points at boundaries
  static List<LatLng> createCleanPolylineFromShapes(List shapes) {
    final List<LatLng> allPoints = [];
    for (int i = 0; i < shapes.length; i++) {
      final shape = shapes[i];
      if (shape is List && shape.isNotEmpty) {
        final List<LatLng> shapePoints = PolylineUtils.parsePolyline(shape);
        if (shapePoints.isNotEmpty) {
          if (i == 0) {
            allPoints.addAll(shapePoints);
          } else {
            final firstPoint = shapePoints.first;
            final lastPoint = allPoints.last;
            final latDiff = (firstPoint.latitude - lastPoint.latitude).abs();
            final lonDiff = (firstPoint.longitude - lastPoint.longitude).abs();
            if (latDiff < 0.00001 && lonDiff < 0.00001) {
              allPoints.addAll(shapePoints.skip(1));
            } else {
              allPoints.addAll(shapePoints);
            }
          }
        }
      }
    }
    return allPoints;
  }

  static List<LatLng> parsePolyline(List<dynamic> polylineData) {
    return PolylineUtils.parsePolyline(polylineData);
  }
}