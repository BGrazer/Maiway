import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelPreferenceScreen extends StatefulWidget {
  final void Function(
    List<String> preferences,
    List<String> modes,
    String passengerType,
    String? cardType,
  ) onPreferencesSaved;

  const TravelPreferenceScreen({
    super.key,
    required this.onPreferencesSaved,
  });

  @override
  State<TravelPreferenceScreen> createState() => _TravelPreferenceScreenState();
}

class _TravelPreferenceScreenState extends State<TravelPreferenceScreen> {
  final Map<String, bool> _preferences = {
    'Fastest': true,
    'Cheapest': true,
    'Convenient': true,
  };

  final Map<String, bool> _modes = {
    'Jeep': true,
    'Bus': true,
    'LRT-1': true,
    'Tricycle': true,
  };

  String _passengerType = 'Regular';
  String? _cardType;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _passengerType = prefs.getString('passenger_type') ?? prefs.getString('passengerType') ?? 'Regular';
      _cardType = prefs.getString('cardType');

      bool? v;
      // Travel prefs (only override if stored value exists)
      v = prefs.getBool('pref_fastest');
      if (v != null) _preferences['Fastest'] = v;
      v = prefs.getBool('pref_Fastest');
      if (v != null) _preferences['Fastest'] = v;

      v = prefs.getBool('pref_cheapest');
      if (v != null) _preferences['Cheapest'] = v;
      v = prefs.getBool('pref_Cheapest');
      if (v != null) _preferences['Cheapest'] = v;

      v = prefs.getBool('pref_convenient');
      if (v != null) _preferences['Convenient'] = v;
      v = prefs.getBool('pref_Convenient');
      if (v != null) _preferences['Convenient'] = v;

      // Modes (handle both old and new keys – override only if stored)
      v = prefs.getBool('mode_jeepney') ?? prefs.getBool('mode_Jeep');
      if (v != null) _modes['Jeep'] = v;

      v = prefs.getBool('mode_bus') ?? prefs.getBool('mode_Bus');
      if (v != null) _modes['Bus'] = v;

      v = prefs.getBool('mode_lrt') ?? prefs.getBool('mode_LRT-1');
      if (v != null) _modes['LRT-1'] = v;

      v = prefs.getBool('mode_tricycle') ?? prefs.getBool('mode_Tricycle');
      if (v != null) _modes['Tricycle'] = v;

      if (_passengerType == 'Discounted') {
        _cardType = 'Student Discount';
      }
    });

    _scrollToBottom();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('passenger_type', _passengerType);
    await prefs.setString('passengerType', _passengerType);
    if (_cardType != null) await prefs.setString('cardType', _cardType!);

    // Save travel preferences under both naming schemes
    await prefs.setBool('pref_fastest', _preferences['Fastest']!);
    await prefs.setBool('pref_Fastest', _preferences['Fastest']!);
    await prefs.setBool('pref_cheapest', _preferences['Cheapest']!);
    await prefs.setBool('pref_Cheapest', _preferences['Cheapest']!);
    await prefs.setBool('pref_convenient', _preferences['Convenient']!);
    await prefs.setBool('pref_Convenient', _preferences['Convenient']!);

    // Save modes under new keys
    await prefs.setBool('mode_jeepney', _modes['Jeep']!);
    await prefs.setBool('mode_bus', _modes['Bus']!);
    await prefs.setBool('mode_lrt', _modes['LRT-1']!);
    await prefs.setBool('mode_tricycle', _modes['Tricycle']!);

    // Keep old keys for backward-compatibility
    await prefs.setBool('mode_Jeep', _modes['Jeep']!);
    await prefs.setBool('mode_Bus', _modes['Bus']!);
    await prefs.setBool('mode_LRT-1', _modes['LRT-1']!);
    await prefs.setBool('mode_Tricycle', _modes['Tricycle']!);
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  String _toBackendMode(String display) {
    switch (display.toLowerCase()) {
      case 'jeep':
      case 'jeepney':
        return 'jeepney';
      case 'bus':
        return 'bus';
      case 'lrt-1':
      case 'lrt':
      case 'train':
        return 'lrt';
      case 'tricycle':
        return 'tricycle';
      default:
        return display.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrainSelected = _modes['LRT-1'] == true || _modes['Train'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PREFERENCE'),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // <--- BOTTOM SPACE ADDED
          children: [
            const _SectionHeader(title: 'Passenger Type'),
            Column(
              children: ['Regular', 'Discounted'].map((type) {
                return RadioListTile<String>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  title: Text(type, style: const TextStyle(fontSize: 13)),
                  value: type,
                  groupValue: _passengerType,
                  onChanged: (String? value) {
                    setState(() {
                      _passengerType = value!;
                      if (_passengerType == 'Discounted') {
                        _cardType = 'Student Discount';
                      } else {
                        _cardType = null;
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const _SectionHeader(title: 'Travel Preferences'),
            ..._preferences.entries.map((entry) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(entry.key, style: const TextStyle(fontSize: 13)),
                ),
                trailing: Switch(
                  value: entry.value,
                  onChanged: (bool value) {
                    setState(() {
                      _preferences[entry.key] = value;
                    });
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
                  child: Text(entry.key, style: const TextStyle(fontSize: 13)),
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

            if (isTrainSelected) ...[
              const _SectionHeader(title: 'LRT/Train Card Type'),
              if (_passengerType == 'Discounted')
                ListTile(
                  dense: true,
                  title: const Text('Student Discount', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.lock, size: 16),
                )
              else
                Column(
                  children: ['Single Journey Card', 'Stored Value Card (Beep Card)']
                      .map((type) {
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      title: Text(type, style: const TextStyle(fontSize: 13)),
                      value: type,
                      groupValue: _cardType,
                      onChanged: (String? value) {
                        setState(() {
                          _cardType = value;
                        });
                      },
                    );
                  }).toList(),
                ),
            ],

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _savePreferences();

                  final selectedPreferences = _preferences.entries
                      .where((e) => e.value)
                      .map((e) => e.key.toLowerCase())
                      .toList();

                  final selectedModes = _modes.entries
                      .where((e) => e.value)
                      .map((e) => _toBackendMode(e.key))
                      .toList();

                  widget.onPreferencesSaved(
                    selectedPreferences,
                    selectedModes,
                    _passengerType,
                    _cardType,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Preferences saved.")),
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

// Backwards compatibility alias so new-engine imports still compile
typedef TravelPreferenceScreenNew = TravelPreferenceScreen;