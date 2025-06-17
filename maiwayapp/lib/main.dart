// lib/main.dart
import 'package:flutter/material.dart';
import 'package:maiwayapp/loginpage.dart';
import 'package:maiwayapp/profile_screen.dart';
import 'package:maiwayapp/map_screen.dart';
import 'package:maiwayapp/travel_preference_page.dart'; // make sure filename matches

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MaiWay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginPage(),
    );
  }
}

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _currentIndex = 0;

  // Store preferences for future use
  String _selectedPreference = 'Fastest';
  List<String> _selectedModes = [];
  String _passengerType = 'Regular';

  List<Widget> _buildPages() {
    return [
      MapScreen(
        selectedPreference: _selectedPreference,
        selectedModes: _selectedModes,
        passengerType: _passengerType,
      ),
      TravelPreferenceScreen(
        onPreferencesSaved: (preference, modes, type) {
          setState(() {
            _selectedPreference = preference;
            _selectedModes = modes;
            _passengerType = type;
          });
        },
      ),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildPages()[_currentIndex],
      bottomNavigationBar: Material(
        elevation: 8,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          backgroundColor: const Color(0xFF6699CC),
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place_rounded),
              label: 'Travel Preferences',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
