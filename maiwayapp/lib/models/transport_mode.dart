import 'package:flutter/material.dart';

enum TransportModeType {
  walk,
  jeepney,
  bus,
  train,
  tricycle,
  angkas, // Motorcycle taxi
  grab, // Ride-hailing service
  taxi,
  unknown,
}

class TransportMode {
  final TransportModeType type;
  final String name;
  final IconData icon;
  final bool isTransit;

  const TransportMode({
    required this.type,
    required this.name,
    required this.icon,
    this.isTransit = false,
  });

  factory TransportMode.fromString(String modeStr) {
    final mode = modeStr.toLowerCase().replaceAll(' ', '');
    switch (mode) {
      case 'walk':
        return TransportMode(type: TransportModeType.walk, name: 'Walk', icon: Icons.directions_walk);
      case 'jeep':
      case 'jeepney':
        return TransportMode(type: TransportModeType.jeepney, name: 'Jeepney', icon: Icons.airport_shuttle, isTransit: true);
      case 'bus':
        return TransportMode(type: TransportModeType.bus, name: 'Bus', icon: Icons.directions_bus, isTransit: true);
      case 'lrt1':
      case 'lrt2':
      case 'mrt3':
      case 'pnr':
      case 'train':
        return TransportMode(type: TransportModeType.train, name: 'Train', icon: Icons.train, isTransit: true);
      case 'tricycle':
        return TransportMode(type: TransportModeType.tricycle, name: 'Tricycle', icon: Icons.moped, isTransit: true);
      case 'angkas':
        return TransportMode(type: TransportModeType.angkas, name: 'Angkas', icon: Icons.two_wheeler, isTransit: true);
      case 'grab':
        return TransportMode(type: TransportModeType.grab, name: 'Grab', icon: Icons.local_taxi, isTransit: true);
       case 'taxi':
        return TransportMode(type: TransportModeType.taxi, name: 'Taxi', icon: Icons.local_taxi, isTransit: true);
      default:
        return TransportMode(type: TransportModeType.unknown, name: 'Unknown', icon: Icons.device_unknown);
    }
  }
}

class TransportModeHelper {
  static IconData getIcon(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return Icons.directions_walk;
      case TransportModeType.jeepney:
        return Icons.airport_shuttle;
      case TransportModeType.bus:
        return Icons.directions_bus;
      case TransportModeType.train:
        return Icons.train;
      case TransportModeType.tricycle:
        return Icons.moped;
      case TransportModeType.angkas:
        return Icons.two_wheeler;
      case TransportModeType.grab:
        return Icons.local_taxi;
      case TransportModeType.taxi:
        return Icons.local_taxi;
      case TransportModeType.unknown:
        return Icons.device_unknown;
    }
  }

  static Color getColor(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return Colors.grey;
      case TransportModeType.jeepney:
        return Colors.blue;
      case TransportModeType.bus:
        return Colors.green;
      case TransportModeType.train:
        return Colors.purple;
      case TransportModeType.tricycle:
        return Colors.orange;
      case TransportModeType.angkas:
        return Colors.purple;
      case TransportModeType.grab:
        return Colors.blue;
      case TransportModeType.taxi:
        return Colors.orange;
      case TransportModeType.unknown:
        return Colors.grey;
    }
  }

  static String getDisplayName(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return 'Walk';
      case TransportModeType.jeepney:
        return 'Jeepney';
      case TransportModeType.bus:
        return 'Bus';
      case TransportModeType.train:
        return 'Train';
      case TransportModeType.tricycle:
        return 'Tricycle';
      case TransportModeType.angkas:
        return 'Angkas';
      case TransportModeType.grab:
        return 'Grab';
      case TransportModeType.taxi:
        return 'Taxi';
      case TransportModeType.unknown:
        return 'Unknown';
    }
  }

  static String getEmoji(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return '🚶';
      case TransportModeType.jeepney:
        return '🚌';
      case TransportModeType.bus:
        return '🚌';
      case TransportModeType.train:
        return '🚇';
      case TransportModeType.tricycle:
        return '🛺';
      case TransportModeType.angkas:
        return '🛺';
      case TransportModeType.grab:
        return '🚖';
      case TransportModeType.taxi:
        return '🚖';
      case TransportModeType.unknown:
        return '❓';
    }
  }

  static TransportMode fromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
      case 'walk':
        return TransportMode(type: TransportModeType.walk, name: 'Walk', icon: Icons.directions_walk);
      case 'jeep':
      case 'jeepney':
        return TransportMode(type: TransportModeType.jeepney, name: 'Jeepney', icon: Icons.airport_shuttle, isTransit: true);
      case 'bus':
        return TransportMode(type: TransportModeType.bus, name: 'Bus', icon: Icons.directions_bus, isTransit: true);
      case 'lrt':
      case 'train':
        return TransportMode(type: TransportModeType.train, name: 'Train', icon: Icons.train, isTransit: true);
      case 'tricycle':
      case 'trike':
        return TransportMode(type: TransportModeType.tricycle, name: 'Tricycle', icon: Icons.moped, isTransit: true);
      case 'angkas':
        return TransportMode(type: TransportModeType.angkas, name: 'Angkas', icon: Icons.two_wheeler, isTransit: true);
      case 'grab':
        return TransportMode(type: TransportModeType.grab, name: 'Grab', icon: Icons.local_taxi, isTransit: true);
      case 'taxi':
        return TransportMode(type: TransportModeType.taxi, name: 'Taxi', icon: Icons.local_taxi, isTransit: true);
      default:
        return TransportMode(type: TransportModeType.unknown, name: 'Unknown', icon: Icons.device_unknown);
    }
  }
} 