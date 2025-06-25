import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelPreferenceScreenNew extends StatefulWidget {
  final Function(List<String>, List<String>, String)? onPreferencesSaved;
  final bool shouldNavigateBack;

  const TravelPreferenceScreenNew({
    Key? key,
    this.onPreferencesSaved,
    this.shouldNavigateBack = false,
  }) : super(key: key);

  @override
  _TravelPreferenceScreenNewState createState() => _TravelPreferenceScreenNewState();
}

class _TravelPreferenceScreenNewState extends State<TravelPreferenceScreenNew> {
  // Travel preferences
  Map<String, bool> _preferences = {
    'Fastest': true,
    'Cheapest': true,
    'Convenient': true,
  };

  // Transport modes
  Map<String, bool> _modes = {
    'Jeepney': true,
    'Bus': true,
    'LRT': true,
    'Tricycle': true,
  };

  // Passenger type
  String _passengerType = 'Regular';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _preferences['Fastest'] = prefs.getBool('pref_fastest') ?? true;
        _preferences['Cheapest'] = prefs.getBool('pref_cheapest') ?? true;
        _preferences['Convenient'] = prefs.getBool('pref_convenient') ?? true;
        
        _modes['Jeepney'] = prefs.getBool('mode_jeepney') ?? true;
        _modes['Bus'] = prefs.getBool('mode_bus') ?? true;
        _modes['LRT'] = prefs.getBool('mode_lrt') ?? true;
        _modes['Tricycle'] = prefs.getBool('mode_tricycle') ?? true;
        
        _passengerType = prefs.getString('passenger_type') ?? 'Regular';
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save travel preferences
      await prefs.setBool('pref_fastest', _preferences['Fastest']!);
      await prefs.setBool('pref_cheapest', _preferences['Cheapest']!);
      await prefs.setBool('pref_convenient', _preferences['Convenient']!);
      
      // Save transport modes
      await prefs.setBool('mode_jeepney', _modes['Jeepney']!);
      await prefs.setBool('mode_bus', _modes['Bus']!);
      await prefs.setBool('mode_lrt', _modes['LRT']!);
      await prefs.setBool('mode_tricycle', _modes['Tricycle']!);
      
      // Save passenger type
      await prefs.setString('passenger_type', _passengerType);
      
      print('Preferences saved successfully');
    } catch (e) {
      print('Error saving preferences: $e');
      throw e;
    }
  }

  void _applyPreferences() async {
    try {
      await _savePreferences();
      
      // Convert preferences to lists for callback
      final selectedPreferences = _preferences.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key.toLowerCase())
          .toList();
      
      // Convert display names to backend mode strings
      final selectedModes = _modes.entries
          .where((entry) => entry.value)
          .map((entry) => _getBackendModeString(entry.key))
          .toList();
      
      // Call callback if provided
      if (widget.onPreferencesSaved != null) {
        widget.onPreferencesSaved!(selectedPreferences, selectedModes, _passengerType);
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: Color(0xFF6699CC),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Only navigate back if this page was pushed (not part of bottom navigation)
      if (widget.shouldNavigateBack && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Convert display names to backend mode strings
  String _getBackendModeString(String displayName) {
    switch (displayName) {
      case 'Jeepney':
        return 'jeepney';
      case 'Bus':
        return 'bus';
      case 'LRT':
        return 'lrt';
      case 'Tricycle':
        return 'tricycle';
      default:
        return displayName.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Preferences'),
        backgroundColor: const Color(0xFF6699CC),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Apply Button at the top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _applyPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6699CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passenger Type Section (moved to top)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Passenger Type',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RadioListTile<String>(
                            title: const Text('Regular'),
                            value: 'Regular',
                            groupValue: _passengerType,
                            onChanged: (String? value) {
                              setState(() {
                                _passengerType = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Discounted'),
                            value: 'Discounted',
                            groupValue: _passengerType,
                            onChanged: (String? value) {
                              setState(() {
                                _passengerType = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Travel Preferences Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Travel Preferences',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._preferences.entries.map((entry) => SwitchListTile(
                            title: Text(entry.key),
                            value: entry.value,
                            onChanged: (bool value) {
                              setState(() {
                                _preferences[entry.key] = value;
                              });
                            },
                          )),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Transport Modes Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transport Modes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._modes.entries.map((entry) => SwitchListTile(
                            title: Text(entry.key),
                            value: entry.value,
                            onChanged: (bool value) {
                              setState(() {
                                _modes[entry.key] = value;
                              });
                            },
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 