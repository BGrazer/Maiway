// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maiwayapp/loginpage.dart';
import 'package:maiwayapp/profile_screen.dart';
import 'map_screen.dart';
import 'travel_preference_page_new.dart';
import 'screens/route_mode_screen.dart';
import 'screens/navigation_screen.dart';
import 'signup.dart';
import 'forgot_password_page.dart';
import 'change_pass.dart';
import 'edit_profile.dart';
import 'admin.dart';
import 'travel_history_screen.dart';
import 'user_report_page.dart';
import 'user_report_history_page.dart';
import 'legalities_page.dart';
import 'developer_policies_page.dart';
import 'transport_policies_page.dart';

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
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Arial'),
          bodyMedium: TextStyle(fontFamily: 'Arial'),
          titleLarge: TextStyle(fontFamily: 'Arial'),
          titleMedium: TextStyle(fontFamily: 'Arial'),
          titleSmall: TextStyle(fontFamily: 'Arial'),
          labelLarge: TextStyle(fontFamily: 'Arial'),
          labelMedium: TextStyle(fontFamily: 'Arial'),
          labelSmall: TextStyle(fontFamily: 'Arial'),
          headlineLarge: TextStyle(fontFamily: 'Arial'),
          headlineMedium: TextStyle(fontFamily: 'Arial'),
          headlineSmall: TextStyle(fontFamily: 'Arial'),
        ),
        primaryTextTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Arial'),
          bodyMedium: TextStyle(fontFamily: 'Arial'),
          titleLarge: TextStyle(fontFamily: 'Arial'),
          titleMedium: TextStyle(fontFamily: 'Arial'),
          titleSmall: TextStyle(fontFamily: 'Arial'),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomeNavigation(),
        '/route-mode': (context) => RouteModeScreen(),
        '/navigation': (context) => NavigationScreen(),
        '/transport-modes': (context) => TravelPreferenceScreenNew(
          onPreferencesSaved: (prefs, modes, passengerType) {
            // Handle preferences saved from route navigation
            print('Preferences saved from route: $prefs, $modes, $passengerType');
          },
          shouldNavigateBack: true,
        ),
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
    MapScreen(),
      TravelPreferenceScreenNew(
        onPreferencesSaved: _handlePreferencesSaved,
      ),
    ProfileScreen(),
  ];
  }

  void _handlePreferencesSaved(List<String> prefs, List<String> modes, String passengerType) {
    // Handle preferences saved from bottom navigation
    print('Preferences saved from bottom nav: $prefs, $modes, $passengerType');
    
    // Show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preferences updated! Routes will use your new settings.'),
        backgroundColor: const Color(0xFF6699CC),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
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

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 28)));
  }
}
