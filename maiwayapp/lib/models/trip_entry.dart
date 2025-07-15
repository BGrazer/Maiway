import 'package:cloud_firestore/cloud_firestore.dart';

class TripEntry {
  final double km;
  final String transportMode;
  final String routeTaken;
  final String routeType;
  final String preference;
  final String passengerType;
  final double fare;
  final Timestamp timestamp;

  TripEntry({
    required this.km,
    required this.transportMode,
    required this.routeTaken,
    required this.routeType,
    required this.preference,
    required this.passengerType,
    required this.fare,
    Timestamp? timestamp,
  }) : timestamp = timestamp ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      'km': km,
      'transportMode': transportMode,
      'routeTaken': routeTaken,
      'routeType': routeType,
      'preference': preference,
      'passengerType': passengerType,
      'fare': fare,
      'timestamp': timestamp,
    };
  }

  static TripEntry fromMap(Map<String, dynamic> map) {
    return TripEntry(
      km: (map['km'] as num).toDouble(),
      transportMode: map['transportMode'] ?? '',
      routeTaken: map['routeTaken'] ?? '',
      routeType: map['routeType'] ?? '',
      preference: map['preference'] ?? '',
      passengerType: map['passengerType'] ?? '',
      fare: (map['fare'] as num).toDouble(),
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }
} 