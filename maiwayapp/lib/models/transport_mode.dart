import 'package:flutter/material.dart';

enum TransportModeType { walk, jeepney, bus, train, tricycle, unknown }

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
        return const TransportMode(
          type: TransportModeType.walk,
          name: 'Walk',
          icon: Icons.directions_walk_rounded,
        );
      case 'jeep':
      case 'jeepney':
        return const TransportMode(
          type: TransportModeType.jeepney,
          name: 'Jeepney',
          icon: Icons.airport_shuttle_rounded,
          isTransit: true,
        );
      case 'bus':
        return const TransportMode(
          type: TransportModeType.bus,
          name: 'Bus',
          icon: Icons.directions_bus_rounded,
          isTransit: true,
        );
      case 'lrt':
      case 'lrt1':
      case 'mrt3':
      case 'pnr':
      case 'train':
        return const TransportMode(
          type: TransportModeType.train,
          name: 'LRT',
          icon: Icons.train_rounded,
          isTransit: true,
        );
      case 'tricycle':
      case 'trike':
        return const TransportMode(
          type: TransportModeType.tricycle,
          name: 'Tricycle',
          icon: Icons.moped_rounded,
          isTransit: true,
        );
      default:
        return const TransportMode(
          type: TransportModeType.unknown,
          name: 'Unknown',
          icon: Icons.help_outline_rounded,
        );
    }
  }
}

class TransportModeHelper {
  // Theme-consistent colors for MAIWAY branding
  static const Color primaryBlue = Color(0xFF1A5276);
  static const Color accentBlue = Color(0xFF6699CC);

  static IconData getIcon(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return Icons.directions_walk_rounded;
      case TransportModeType.jeepney:
        return Icons.airport_shuttle_rounded;
      case TransportModeType.bus:
        return Icons.directions_bus_rounded;
      case TransportModeType.train:
        return Icons.train_rounded;
      case TransportModeType.tricycle:
        return Icons.moped_rounded;
      case TransportModeType.unknown:
        return Icons.help_outline_rounded;
    }
  }

  static Color getColor(TransportMode mode) {
    switch (mode.type) {
      case TransportModeType.walk:
        return const Color(0xFF7F8C8D); // Professional Grey
      case TransportModeType.jeepney:
        return primaryBlue; // Use Main App Color
      case TransportModeType.bus:
        return const Color(0xFF27AE60); // Vibrant Green
      case TransportModeType.train:
        return const Color(0xFF8E44AD); // Deep Purple
      case TransportModeType.tricycle:
        return const Color(0xFFE67E22); // Safety Orange
      case TransportModeType.unknown:
        return Colors.blueGrey;
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
        return 'LRT / Train';
      case TransportModeType.tricycle:
        return 'Tricycle';
      case TransportModeType.unknown:
        return 'Other';
    }
  }
}
