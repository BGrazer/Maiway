import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'loginpage.dart';
import 'change_pass.dart';
import 'travel_history_screen.dart';
import 'admin.dart';
import 'user_report_history_page.dart';
import 'edit_profile.dart';
import 'legalities_page.dart';
import 'fare_matrix_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Flattering Darker Blue Palette
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color slateBackground = const Color.fromARGB(
    255,
    145,
    201,
    241,
  ); // A more "flattering" muted blue
  final Color accentBlue = const Color(0xFF3F7399);

  bool isAdmin = false;
  late Future<DocumentSnapshot<Map<String, dynamic>>> userData;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      userData = FirebaseFirestore.instance.collection('users').doc(uid).get();
    }
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final role = doc.data()?['role'] ?? 'user';
      setState(() {
        isAdmin = role == 'admin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slateBackground, // Updated darker blue background
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryBlue));
          }

          final data = snapshot.data!.data() ?? {};
          final fullName = data['name'] ?? 'Unnamed User';
          final contactNumber = data['contactNumber'] ?? 'No Contact Number';
          final initials = _getInitials(fullName);

          return SafeArea(
            bottom: false, // Allows spacer to handle the bottom nav
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  // FIXED: Cleaner Header Title
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A5276),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // YOUR ORIGINAL LOGIC: Re-styled Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: primaryBlue,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A5276),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                contactNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  _sectionTitle('ACCOUNT'),

                  _buildSettingsTile(
                    icon: Icons.person_rounded,
                    title: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ).then((_) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          setState(() {
                            userData =
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .get();
                          });
                        }
                      });
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.vpn_key_rounded,
                    title: 'Change Password',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.map_rounded,
                    title: 'Travel History',
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelHistoryScreen(userId: uid),
                          ),
                        );
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.report_problem_rounded,
                    title: 'Report History',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserReportHistoryPage(),
                          ),
                        ),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle('INFORMATION'),

                  _buildSettingsTile(
                    icon: Icons.gavel_rounded,
                    title: 'Legalities and Policies',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalitiesPage(),
                          ),
                        ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.table_chart_rounded,
                    title: 'Fare Matrices',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FareMatrixPage(),
                          ),
                        ),
                  ),

                  const SizedBox(height: 24),
                  _sectionTitle('ACTIONS'),

                  if (isAdmin)
                    _buildSettingsTile(
                      icon: Icons.admin_panel_settings,
                      title: 'Admin Dashboard',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          ),
                    ),

                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    iconColor: Colors.red.shade700,
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                        (route) => false,
                      );
                    },
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A5276),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: iconColor ?? primaryBlue),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3436),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: Colors.black26,
        ),
        onTap: onTap,
      ),
    );
  }
}
