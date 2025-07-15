import 'package:latlong2/latlong.dart';

class GeocodingHelper {
  /// Check if a point is within Manila city limits
  static bool isWithinManila(LatLng location, List<LatLng> manilaBoundary) {
    return _isPointInPolygon(location, manilaBoundary);
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  static bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length - 1; i++) {
      LatLng vertex1 = polygon[i];
      LatLng vertex2 = polygon[i + 1];
      if (_rayIntersectsSegment(point, vertex1, vertex2)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  /// Ray casting algorithm helper - check if ray intersects with line segment
  static bool _rayIntersectsSegment(LatLng point, LatLng vertex1, LatLng vertex2) {
    double x = point.longitude;
    double y = point.latitude;
    double x1 = vertex1.longitude;
    double y1 = vertex1.latitude;
    double x2 = vertex2.longitude;
    double y2 = vertex2.latitude;

    if (y1 > y == y2 > y) return false;
    double slope = (x2 - x1) / (y2 - y1);
    double intersectX = x1 + slope * (y - y1);
    return x < intersectX;
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Get center point of a list of coordinates
  static LatLng getCenterPoint(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(14.5995, 120.9842); // Default to Manila center
    }

    double totalLat = 0;
    double totalLng = 0;

    for (LatLng point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return LatLng(
      totalLat / points.length,
      totalLng / points.length,
    );
  }

  /// Validate if coordinates are valid Manila coordinates
  static bool isValidManilaCoordinate(LatLng location) {
    // Manila rough bounding box
    const double minLat = 14.50;
    const double maxLat = 14.70;
    const double minLng = 120.90;
    const double maxLng = 121.10;

    return location.latitude >= minLat &&
           location.latitude <= maxLat &&
           location.longitude >= minLng &&
           location.longitude <= maxLng;
  }
}