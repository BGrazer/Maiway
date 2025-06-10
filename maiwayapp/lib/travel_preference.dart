// lib/travel_preference.dart
import 'package:flutter/material.dart';

class TravelPreferenceScreen extends StatefulWidget {
  const TravelPreferenceScreen({super.key});

  @override
  State<TravelPreferenceScreen> createState() => _TravelPreferenceScreenState();
}

class _TravelPreferenceScreenState extends State<TravelPreferenceScreen> {
  final Map<String, bool> _preferences = {
    'Fastest': true,
    'Cheapest': false,
    'Convenient': false,
  };

  final Map<String, bool> _modes = {
    'Jeepney': false,
    'E-Jeep': false,
    'LRT': false,
    'Tricycle': false,
    'E-Tricycle': false,
  };

  void _selectOnlyOne(String selected) {
    setState(() {
      _preferences.updateAll((key, value) => key == selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PREFERENCE'),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const _SectionHeader(title: 'Travel Preferences'),
          ..._preferences.entries.map((entry) {
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              trailing: Switch(
                value: entry.value,
                onChanged: (bool value) {
                  if (value) _selectOnlyOne(entry.key);
                },
                activeColor: Colors.green,
              ),
            );
          }).toList(),

          const _SectionHeader(title: 'Mode Priority'),
          ..._modes.entries.map((entry) {
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              value: entry.value,
              onChanged: (bool? value) {
                setState(() {
                  _modes[entry.key] = value!;
                });
              },
              checkColor: Colors.white,
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }).toList(),

          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Keep on the page, you can handle data transmission elsewhere
              },
              icon: const Icon(Icons.check),
              label: const Text("Apply Preferences"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
