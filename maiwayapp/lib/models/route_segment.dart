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
  });

  factory RouteSegment.fromMap(Map<String, dynamic> map) {
    List<LatLng> coords = [];
    if (map['polyline'] is List) {
      coords = PolylineUtils.parsePolyline(map['polyline']);
    }
    return RouteSegment(
      mode: TransportMode.fromString(map['mode']?.toString() ?? 'unknown'),
      instruction: map['instruction']?.toString() ?? 'No instruction provided',
      name: map['name']?.toString() ?? 'Unnamed Segment',
      coordinates: coords,
      polyline: coords,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      fromStop: map['from_stop']?['name']?.toString() ?? 'Start of segment',
      toStop: map['to_stop']?['name']?.toString() ?? 'End of segment',
      detailedInstructions: map['detailed_instructions'] as List<dynamic>? ?? [],
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