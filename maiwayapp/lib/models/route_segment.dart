import 'package:latlong2/latlong.dart';
import './transport_mode.dart';

class RouteSegment {
  final TransportMode mode;
  final String instruction;
  final String name;
  final List<LatLng> coordinates;
  final double distance;
  final int time;
  final double fare;
  final String fromStop;
  final String toStop;

  RouteSegment({
    required this.mode,
    required this.instruction,
    required this.name,
    required this.coordinates,
    required this.distance,
    required this.time,
    this.fare = 0.0,
    required this.fromStop,
    required this.toStop,
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
      time: (map['time'] as num?)?.toInt() ?? 0,
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      fromStop: map['from_stop']?['name']?.toString() ?? 'Start of segment',
      toStop: map['to_stop']?['name']?.toString() ?? 'End of segment',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'instruction': instruction,
      'name': name,
      'shape': coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      'distance': distance,
      'time': time,
      'fare': fare,
      'from_stop': {'name': fromStop},
      'to_stop': {'name': toStop},
    };
  }

  @override
  String toString() {
    return 'RouteSegment(mode: ${mode.name}, from: $fromStop, to: $toStop, distance: ${distance}m, time: ${time}min, fare: ₱$fare)';
  }
} 