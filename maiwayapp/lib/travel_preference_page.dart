import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelPreferenceScreen extends StatefulWidget {
  final void Function(List<String> preferences, List<String> modes, String passengerType) onPreferencesSaved;

  const TravelPreferenceScreen({
    super.key,
    required this.onPreferencesSaved,
  });

  @override
  State<TravelPreferenceScreen> createState() => _TravelPreferenceScreenState();
}

class _TravelPreferenceScreenState extends State<TravelPreferenceScreen> {
  final Map<String, bool> _preferences = {
    'Fastest': true,     // Default to true
    'Cheapest': true,    // Default to true
    'Convenient': true,  // Default to true
  };

  final Map<String, bool> _modes = {
    'Jeep': true,      // Default to true
    'Bus': true,       // Default to true
    'LRT': true,       // Default to true
    'Tricycle': true,  // Default to true
    'LRT 2': true,     // Default to true
  };

  String _passengerType = 'Regular';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _passengerType = prefs.getString('passengerType') ?? 'Regular';

      // Load preferences with defaults - all ON by default
      _preferences['Fastest'] = prefs.getBool('pref_Fastest') ?? true;
      _preferences['Cheapest'] = prefs.getBool('pref_Cheapest') ?? true;
      _preferences['Convenient'] = prefs.getBool('pref_Convenient') ?? true;

      // Load modes with defaults - all ON by default
      _modes['Jeep'] = prefs.getBool('mode_Jeep') ?? true;
      _modes['Bus'] = prefs.getBool('mode_Bus') ?? true;
      _modes['LRT'] = prefs.getBool('mode_LRT') ?? true;
      _modes['Tricycle'] = prefs.getBool('mode_Tricycle') ?? true;
      _modes['LRT 2'] = prefs.getBool('mode_LRT 2') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    print('🔍 DEBUG: _savePreferences method called');
    try {
      final prefs = await SharedPreferences.getInstance();
      print('🔍 DEBUG: SharedPreferences instance obtained');
      
      await prefs.setString('passengerType', _passengerType);
      print('🔍 DEBUG: Passenger type saved: $_passengerType');

      for (var entry in _preferences.entries) {
        await prefs.setBool('pref_${entry.key}', entry.value);
        print('🔍 DEBUG: Saved preference ${entry.key}: ${entry.value}');
      }

      for (var entry in _modes.entries) {
        await prefs.setBool('mode_${entry.key}', entry.value);
        print('🔍 DEBUG: Saved mode ${entry.key}: ${entry.value}');
      }
      
      print('🔍 DEBUG: All preferences saved successfully');
    } catch (e) {
      print('❌ DEBUG: Error in _savePreferences: $e');
      print('❌ DEBUG: Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PREFERENCE'),
        backgroundColor: const Color(0xFF6699CC),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[50],
        child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
            // Passenger Type Section
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Passenger Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6699CC),
                      ),
                    ),
                  ),
                  ...['Regular', 'Discounted'].map((type) {
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      title: Text(type, style: const TextStyle(fontSize: 16)),
                      value: type,
                      groupValue: _passengerType,
                      onChanged: (String? value) {
                        setState(() {
                          _passengerType = value!;
                        });
                      },
            );
          }).toList(),
                ],
              ),
            ),

            // Travel Preferences Section
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
              borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Travel Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6699CC),
                      ),
            ),
          ),
                  ..._preferences.entries.map((entry) {
                    return ListTile(
              dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      title: Text(entry.key, style: const TextStyle(fontSize: 16)),
                      trailing: Switch(
              value: entry.value,
                        onChanged: (bool value) {
                          setState(() {
                            _preferences[entry.key] = value;
                          });
              },
                        activeColor: const Color(0xFF6699CC),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            // Transport Modes Section
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Transport Modes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6699CC),
                      ),
                    ),
                  ),
                  ..._modes.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      title: Text(entry.key, style: const TextStyle(fontSize: 16)),
                      trailing: Switch(
                        value: entry.value,
                        onChanged: (bool value) {
                          setState(() {
                            _modes[entry.key] = value;
                          });
                        },
                        activeColor: const Color(0xFF6699CC),
              ),
            );
          }).toList(),
                ],
              ),
            ),

            // Apply Preferences Button
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    print('🔍 DEBUG: Apply Preferences button pressed');
                    try {
                      print('🔍 DEBUG: Starting to save preferences...');
                      await _savePreferences();
                      print('🔍 DEBUG: Preferences saved successfully');
                      
                      // Convert preferences to lists for callback
                      print('🔍 DEBUG: Converting preferences to lists...');
                      final selectedPreferences = _preferences.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key.toLowerCase())
                          .toList();
                      print('🔍 DEBUG: Selected preferences: $selectedPreferences');
                      
                      final selectedModes = _modes.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList();
                      print('🔍 DEBUG: Selected modes: $selectedModes');
                      print('🔍 DEBUG: Passenger type: $_passengerType');

                      // Call the callback function
                      print('🔍 DEBUG: About to call onPreferencesSaved callback...');
                      widget.onPreferencesSaved(selectedPreferences, selectedModes, _passengerType);
                      print('🔍 DEBUG: Callback executed successfully');
                      
                      // Show success message
                      print('🔍 DEBUG: Checking if widget is mounted...');
                      if (mounted) {
                        print('🔍 DEBUG: Widget is mounted, showing success message...');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Preferences saved successfully!'),
                            backgroundColor: Color(0xFF6699CC),
                          ),
                        );
                        print('🔍 DEBUG: Success message shown');
                      } else {
                        print('🔍 DEBUG: Widget is not mounted, skipping success message');
                      }
                      
                      // Navigate back immediately
                      print('🔍 DEBUG: About to navigate back...');
                      if (mounted) {
                        print('🔍 DEBUG: Widget is mounted, navigating back...');
                        Navigator.of(context).pop();
                        print('🔍 DEBUG: Navigation completed');
                      } else {
                        print('🔍 DEBUG: Widget is not mounted, cannot navigate');
                      }
                    } catch (e) {
                      print('❌ DEBUG: Error occurred: $e');
                      print('❌ DEBUG: Error stack trace: ${StackTrace.current}');
                      if (mounted) {
                        print('🔍 DEBUG: Showing error message...');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving preferences: $e'),
                            backgroundColor: Colors.red,
      ),
    );
  }
}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6699CC),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}