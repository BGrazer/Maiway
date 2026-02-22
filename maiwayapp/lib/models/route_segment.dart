import 'package:latlong2/latlong.dart';
import './transport_mode.dart';
import '../utils/polyline_utils.dart';

class RouteSegment {
  final TransportMode mode;
  final String instruction;
  final String name;
  final List<LatLng> coordinates;
  final List<LatLng> polyline;
  final double distance;
  final double fare;
  final String fromStop;
  final String toStop;
  final List<dynamic> detailedInstructions;
  /// Fallback for polyline when backend sends empty/short polyline (route-mode map)
  final double? fromLat;
  final double? fromLon;
  final double? toLat;
  final double? toLon;

  RouteSegment({
    required this.mode,
    required this.instruction,
    required this.name,
    required this.coordinates,
    required this.polyline,
    required this.distance,
    this.fare = 0.0,
    required this.fromStop,
    required this.toStop,
    this.detailedInstructions = const [],
    this.fromLat,
    this.fromLon,
    this.toLat,
    this.toLon,
  });

  factory RouteSegment.fromMap(Map<String, dynamic> map) {
    List<LatLng> coords = [];
    if (map['polyline'] is List) {
      coords = PolylineUtils.parsePolyline(map['polyline']);
    }
    final fromStopMap = map['from_stop'];
    final toStopMap = map['to_stop'];
    double? fl = fromStopMap is Map && fromStopMap['lat'] != null ? (fromStopMap['lat'] as num).toDouble() : null;
    double? fln = fromStopMap is Map && fromStopMap['lon'] != null ? (fromStopMap['lon'] as num).toDouble() : null;
    double? tl = toStopMap is Map && toStopMap['lat'] != null ? (toStopMap['lat'] as num).toDouble() : null;
    double? tln = toStopMap is Map && toStopMap['lon'] != null ? (toStopMap['lon'] as num).toDouble() : null;
    return RouteSegment(
      mode: TransportMode.fromString(map['mode']?.toString() ?? 'unknown'),
      instruction: map['instruction']?.toString() ?? 'No instruction provided',
      name: map['name']?.toString() ?? 'Unnamed Segment',
      coordinates: coords,
      polyline: coords,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      fromStop: fromStopMap is Map ? (fromStopMap['name']?.toString() ?? 'Start of segment') : 'Start of segment',
      toStop: toStopMap is Map ? (toStopMap['name']?.toString() ?? 'End of segment') : 'End of segment',
      detailedInstructions: map['detailed_instructions'] as List<dynamic>? ?? [],
      fromLat: fl,
      fromLon: fln,
      toLat: tl,
      toLon: tln,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'instruction': instruction,
      'name': name,
      'shape': coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      'distance': distance,
      'fare': fare,
      'from_stop': {'name': fromStop},
      'to_stop': {'name': toStop},
      'detailed_instructions': detailedInstructions,
    };
  }

  @override
  String toString() {
    return 'RouteSegment(mode: [1m${mode.name}[0m, from: $fromStop, to: $toStop, distance: ${distance}m, fare: ₱$fare)';
  }
} 