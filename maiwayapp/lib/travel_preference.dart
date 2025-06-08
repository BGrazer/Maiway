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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6699CC),
      body: SafeArea(
        child: Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Travel Preferences',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Travel Preference: Vertical Switches
              Column(
                children: _preferences.entries.map((entry) {
                  return SwitchListTile(
                    title: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: entry.value,
                    onChanged: (bool value) {
                      setState(() {
                        _preferences[entry.key] = value;
                      });
                    },
                    activeColor: Colors.amberAccent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              const Text(
                'Mode Priority',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // ✅ Mode Priority: Vertical Checkboxes
              Expanded(
                child: ListView(
                  children: _modes.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(
                        entry.key,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: entry.value,
                      onChanged: (bool? value) {
                        setState(() {
                          _modes[entry.key] = value!;
                        });
                      },
                      checkColor: Colors.black,
                      activeColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Process your preferences here
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Apply Preferences"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
