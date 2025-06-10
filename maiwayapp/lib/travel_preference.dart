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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Styled like Settings screen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PREFERENCE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Travel Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),

              // Travel Preferences (Switches)
              Column(
                children: _preferences.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Switch(
                          value: entry.value,
                          onChanged: (bool value) {
                            if (value) _selectOnlyOne(entry.key);
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Mode Priority',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),

              // Mode Checkboxes
              Expanded(
                child: ListView(
                  children: _modes.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                        title: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.key,
                            style: const TextStyle(color: Colors.black),
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
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Apply Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // No navigation or callback for now
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Preferences saved!"),
                        duration: Duration(seconds: 1),
                      ),
                    );
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
        ),
      ),
    );
  }
}
