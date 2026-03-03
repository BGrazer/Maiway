import 'package:flutter/material.dart';
import 'package:maiwayapp/loginpage.dart';
import 'package:maiwayapp/profile_screen.dart';
import 'package:maiwayapp/map_screen.dart';
import 'package:maiwayapp/travel_preference_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maiwayapp/screens/route_mode_screen.dart';
import 'package:maiwayapp/screens/navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only once
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MaiWay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/route-mode': (context) => RouteModeScreen(),
        '/navigation': (context) => NavigationScreen(),
      },
      home: user != null ? const HomeNavigation() : LoginPage(),
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

  List<String> _selectedPreferences = [];
  List<String> _selectedModes = [];
  String _passengerType = 'Regular';
  String? _cardType;

  void _updatePreferences(
    List<String> preferences,
    List<String> modes,
    String type,
    String? cardType,
  ) {
    setState(() {
      _selectedPreferences = preferences;
      _selectedModes = modes;
      _passengerType = type;
      _cardType = cardType;
    });
  }

  List<Widget> _buildPages() {
    return [
      MapScreen(
        selectedPreferences: _selectedPreferences,
        selectedModes: _selectedModes,
        passengerType: _passengerType,
        cardType: _cardType,
      ),
      TravelPreferenceScreen(
        onPreferencesSaved: _updatePreferences,
        isVisible: _currentIndex == 1,
        onApply: () {
          setState(() {
            _currentIndex = 0;
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
      // --- UPDATED BOTTOM NAVIGATION BAR ONLY ---
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Floating margin
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: Colors.white.withOpacity(0.2),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(color: Colors.white),
              ),
            ),
            child: NavigationBar(
              height: 70,
              backgroundColor: const Color(0xFF6699CC),
              selectedIndex: _currentIndex,
              // Always show labels for accessibility
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
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
                  label: 'Preferences',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 28)));
  }
}
