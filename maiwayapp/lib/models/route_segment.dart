import 'package:latlong2/latlong.dart';
import './transport_mode.dart';

class RouteSegment {
  final TransportMode mode;
  final String instruction;
  final String name;
  final List<LatLng> coordinates;
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
    required this.distance,
    this.fare = 0.0,
    required this.fromStop,
    required this.toStop,
    this.detailedInstructions = const [],
  });

  factory RouteSegment.fromMap(Map<String, dynamic> map) {
    // Safely parse coordinates from backend format [[lng, lat], [lng, lat], ...]
    List<LatLng> coords = [];
    if (map['shape'] is List) {
      final coordList = map['shape'] as List<dynamic>;
      for (final coord in coordList) {
        if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
          coords.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
        }
      }
    }

    return RouteSegment(
      mode: TransportMode.fromString(map['mode']?.toString() ?? 'unknown'),
      instruction: map['instruction']?.toString() ?? 'No instruction provided',
      name: map['name']?.toString() ?? 'Unnamed Segment',
      coordinates: coords,
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
    return 'RouteSegment(mode: ${mode.name}, from: $fromStop, to: $toStop, distance: ${distance}m, fare: ₱$fare)';
  }
} 