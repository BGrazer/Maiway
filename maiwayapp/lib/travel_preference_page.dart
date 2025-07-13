import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelPreferenceScreen extends StatefulWidget {
  final void Function(
    List<String> preferences,
    List<String> modes,
    String passengerType,
    String? cardType,
  )
  onPreferencesSaved;

  const TravelPreferenceScreen({super.key, required this.onPreferencesSaved});

  @override
  State<TravelPreferenceScreen> createState() => _TravelPreferenceScreenState();
}

class _TravelPreferenceScreenState extends State<TravelPreferenceScreen> {
  final Map<String, bool> _preferences = {
    'Fastest': false,
    'Cheapest': false,
    'Convenient': false,
  };

  final Map<String, bool> _modes = {
    'Jeep': false,
    'Bus': false,
    'LRT-1': false,
    'Tricycle': false,
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
      _passengerType = prefs.getString('passengerType') ?? 'Regular';
      _cardType = prefs.getString('cardType');

      for (var key in _preferences.keys) {
        _preferences[key] = prefs.getBool('pref_$key') ?? _preferences[key]!;
      }

      for (var key in _modes.keys) {
        _modes[key] = prefs.getBool('mode_$key') ?? _modes[key]!;
      }

      if (_passengerType == 'Discounted') {
        _cardType = 'Student Discount';
      }
    });

    _scrollToBottom();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('passengerType', _passengerType);
    if (_cardType != null) await prefs.setString('cardType', _cardType!);

    for (var entry in _preferences.entries) {
      await prefs.setBool('pref_${entry.key}', entry.value);
    }

    for (var entry in _modes.entries) {
      await prefs.setBool('mode_${entry.key}', entry.value);
    }
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
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ), // <--- BOTTOM SPACE ADDED
          children: [
            const _SectionHeader(title: 'Passenger Type'),
            Column(
              children:
                  ['Regular', 'Discounted'].map((type) {
                    return RadioListTile<String>(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                      ),
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
                  title: const Text(
                    'Student Discount',
                    style: TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.lock, size: 16),
                )
              else
                Column(
                  children:
                      [
                        'Single Journey Card',
                        'Stored Value Card (Beep Card)',
                      ].map((type) {
                        return RadioListTile<String>(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                          ),
                          title: Text(
                            type,
                            style: const TextStyle(fontSize: 13),
                          ),
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

                  final selectedPreferences =
                      _preferences.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();

                  final selectedModes =
                      _modes.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
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
