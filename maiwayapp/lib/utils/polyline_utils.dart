import 'package:latlong2/latlong.dart';

class PolylineUtils {
  /// Parse polyline from various formats into a list of LatLng objects
  static List<LatLng> parsePolyline(dynamic polyline) {
    if (polyline is List<LatLng>) return polyline;
    if (polyline is List) {
      try {
        return polyline.map((p) {
          if (p is LatLng) return p;
          if (p is List && p.length >= 2) {
            // Handle both [lon, lat] and [lat, lon] formats
            // Assume [lon, lat] format from backend (standard GeoJSON format)
            double val0 = p[0] is num ? (p[0] as num).toDouble() : 0.0;
            double val1 = p[1] is num ? (p[1] as num).toDouble() : 0.0;
            
            // Check if first value looks like latitude
            if (val0.abs() <= 90 && val1.abs() <= 180) {
              // It's already [lat, lon] format
              return LatLng(val0, val1);
            } else {
              // It's [lon, lat] format, so swap
              return LatLng(val1, val0);
            }
          }
          if (p is Map) {
            // Handle {latitude, longitude} format
            if (p.containsKey('latitude') && p.containsKey('longitude')) {
              return LatLng(
                (p['latitude'] is num) ? (p['latitude'] as num).toDouble() : 0.0,
                (p['longitude'] is num) ? (p['longitude'] as num).toDouble() : 0.0
              );
            }
            // Handle {lat, lng} format
            if (p.containsKey('lat') && p.containsKey('lng')) {
              return LatLng(
                (p['lat'] is num) ? (p['lat'] as num).toDouble() : 0.0,
                (p['lng'] is num) ? (p['lng'] as num).toDouble() : 0.0
              );
            }
          }
          print('⚠️ Invalid polyline point format: $p, using fallback (0,0)');
          return LatLng(0, 0);
        }).toList();
      } catch (e) {
        print('🟥 Error parsing polyline: $e');
        return [];
      }
    }
    return [];
  }

  /// Create a robust polyline with fallback to origin-destination line if needed
  static List<LatLng> robustPolyline(dynamic polyline, LatLng origin, LatLng destination) {
    final parsed = parsePolyline(polyline);
    if (parsed.isEmpty) {
      print('🟥 Polyline empty, using fallback [origin, destination]');
      return [origin, destination];
    }
    final first = parsed.first;
    final allSame = parsed.every((p) => p.latitude == first.latitude && p.longitude == first.longitude);
    if (allSame) {
      print('🟥 Polyline all points same, using fallback [origin, destination]');
      return [origin, destination];
    }
    return parsed;
  }
}