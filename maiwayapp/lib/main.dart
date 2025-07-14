import 'package:flutter/material.dart';
import 'package:maiwayapp/loginpage.dart';
import 'package:maiwayapp/profile_screen.dart';
import 'package:maiwayapp/map_screen.dart';
import 'package:maiwayapp/travel_preference_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/route_mode_screen.dart';
import 'screens/navigation_screen.dart';

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
      home: user != null ? const HomeNavigation() : LoginPage(),
      routes: {
        '/home': (context) => const HomeNavigation(),
        '/route-mode': (context) => RouteModeScreen(),
        '/navigation': (context) => const NavigationScreen(),
        '/transport-modes': (context) => TravelPreferenceScreen(onPreferencesSaved: (_, __, ___, ____) {}),
      },
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
      MapScreen(),
      TravelPreferenceScreen(onPreferencesSaved: _updatePreferences),
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

// Optional: Keeps old PlaceholderScreen in case it's still used somewhere
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 28)));
  }
}
