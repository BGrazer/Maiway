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
  final VoidCallback onApply;
  final bool isVisible;

  const TravelPreferenceScreen({
    super.key,
    required this.onPreferencesSaved,
    required this.onApply,
    this.isVisible = true,
  });

  @override
  State<TravelPreferenceScreen> createState() => _TravelPreferenceScreenState();
}

class _TravelPreferenceScreenState extends State<TravelPreferenceScreen> {
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);

  final Map<String, bool> _preferences = {
    'Fastest': true,
    'Cheapest': false,
    'Convenient': false,
  };

  final Map<String, bool> _modes = {
    'Jeep': false,
    'Bus': true,
    'LRT-1': true,
    'Tricycle': false,
  };

  String _passengerType = 'Regular';
  String? _cardType;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _passengerType = prefs.getString('passengerType') ?? 'Regular';
      _cardType = prefs.getString('cardType');
      _preferences.forEach((key, _) {
        _preferences[key] =
            prefs.getBool(_prefKeyFor(key)) ?? _preferences[key]!;
      });
      _modes.forEach((key, _) {
        _modes[key] = prefs.getBool(_modeKeyFor(key)) ?? _modes[key]!;
      });
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('passengerType', _passengerType);
    if (_cardType != null) await prefs.setString('cardType', _cardType!);
    for (var entry in _preferences.entries) {
      await prefs.setBool(_prefKeyFor(entry.key), entry.value);
    }
    for (var entry in _modes.entries) {
      await prefs.setBool(_modeKeyFor(entry.key), entry.value);
    }
  }

  String _prefKeyFor(String display) => 'pref_${display.toLowerCase()}';
  String _modeKeyFor(String display) =>
      'mode_${display.toLowerCase().replaceAll('-', '')}';

  @override
  Widget build(BuildContext context) {
    final isTrainSelected = _modes['LRT-1'] == true;

    return Container(
      color: skyBlueBackground,
      child: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            width: double.infinity,
            color: const Color(0xFF1A5276),
            child: const Text(
              'TRAVEL PREFERENCE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                _buildSectionTitle('PASSENGER PROFILE'),
                _buildPassengerProfileCards(),
                const SizedBox(height: 24),
                _buildSectionTitle('PRIORITIZE BY'),
                _buildVerticalPreferenceList(),
                const SizedBox(height: 24),
                _buildSectionTitle('TRANSPORT MODES'),
                _buildVerticalModeList(),
                if (isTrainSelected) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('TRAIN CARD TYPE'),
                  _buildTrainCardSelector(),
                ],
                const SizedBox(height: 40), // Space before the button
              ],
            ),
          ),

          // FLOATING BUTTON (No white background, sits just above nav bar)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              100,
            ), // Pushed up by 100 to stay above main nav bar
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await _savePreferences();
                  final selectedPrefs =
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
                    selectedPrefs,
                    selectedModes,
                    _passengerType,
                    _cardType,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Preferences Saved Successfully!"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  widget.onApply();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "APPLY PREFERENCES",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSED UI COMPONENTS ---

  Widget _profileOptionCard(String type, IconData icon) {
    bool isSelected = _passengerType == type;
    return Expanded(
      child: GestureDetector(
        onTap:
            () => setState(() {
              _passengerType = type;
              _cardType = (type == 'Discounted') ? 'Student Discount' : null;
            }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : primaryBlue,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerProfileCards() {
    return Row(
      children: [
        _profileOptionCard('Regular', Icons.person_outline),
        const SizedBox(width: 15),
        _profileOptionCard('Discounted', Icons.badge_outlined),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: primaryBlue,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildVerticalPreferenceList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children:
            _preferences.keys.map((pref) {
              return SwitchListTile(
                title: Text(
                  pref,
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                value: _preferences[pref]!,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _preferences[pref] = val),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildVerticalModeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children:
            _modes.keys.map((mode) {
              return CheckboxListTile(
                title: Text(
                  mode,
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                value: _modes[mode],
                activeColor: primaryBlue,
                onChanged: (val) => setState(() => _modes[mode] = val!),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildTrainCardSelector() {
    if (_passengerType == 'Discounted') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Special Discount Applied",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children:
            ['Single Journey Card', 'Stored Value Card (Beep)'].map((type) {
              return RadioListTile<String>(
                title: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: type,
                groupValue: _cardType,
                activeColor: primaryBlue,
                onChanged: (v) => setState(() => _cardType = v),
              );
            }).toList(),
      ),
    );
  }
}
