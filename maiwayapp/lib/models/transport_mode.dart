import 'package:flutter/material.dart';

enum TransportModeType {
  walk,
  jeepney,
  bus,
  train,
  tricycle,
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
      case 'walking':
        return TransportMode(type: TransportModeType.walk, name: 'Walk', icon: Icons.directions_walk);
      case 'jeep':
      case 'jeepney':
        return TransportMode(type: TransportModeType.jeepney, name: 'Jeepney', icon: Icons.airport_shuttle, isTransit: true);
      case 'bus':
        return TransportMode(type: TransportModeType.bus, name: 'Bus', icon: Icons.directions_bus, isTransit: true);
      case 'lrt':
      case 'lrt1':
      case 'mrt3':
      case 'pnr':
      case 'train':
        return TransportMode(type: TransportModeType.train, name: 'LRT', icon: Icons.train, isTransit: true);
      case 'tricycle':
      case 'trike':
        return TransportMode(type: TransportModeType.tricycle, name: 'Tricycle', icon: Icons.moped, isTransit: true);
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
        return 'LRT';
      case TransportModeType.tricycle:
        return 'Tricycle';
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
        return TransportMode(type: TransportModeType.train, name: 'LRT', icon: Icons.train, isTransit: true);
      case 'tricycle':
      case 'trike':
        return TransportMode(type: TransportModeType.tricycle, name: 'Tricycle', icon: Icons.moped, isTransit: true);
      default:
        return TransportMode(type: TransportModeType.unknown, name: 'Unknown', icon: Icons.device_unknown);
    }
  }
} 