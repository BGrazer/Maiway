import 'package:flutter/material.dart';
import 'change_pass.dart';
<<<<<<< Updated upstream
import 'user_report_page.dart';
import 'travel_history_screen.dart';
import 'admin.dart';
=======
import 'travel_history_screen.dart';
import 'admin.dart';
import 'user_report_history_page.dart';
import 'edit_profile.dart';
import 'legalities_page.dart';
import 'transport_policies_page.dart';
import 'developer_policies_page.dart';
>>>>>>> Stashed changes


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
<<<<<<< Updated upstream
          const SectionHeader(title: 'Account'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () {},
          ),
=======
          //ACCOUNT
const SectionHeader(title: 'Account'),
_buildSettingsTile(
  icon: Icons.person,
  title: 'Edit Profile',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>  EditProfileScreen()),
    );
  },
),

>>>>>>> Stashed changes
          _buildSettingsTile(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
<<<<<<< Updated upstream
          _buildSettingsTile(
            icon: Icons.place,
            title: 'Travel History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TravelHistoryScreen()
                  
              ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.outlined_flag,
            title: 'Report History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddReportScreen(),
                ),
              );
            },
          ),
         _buildSettingsTile(
=======
_buildSettingsTile(
  icon: Icons.place,
  title: 'Travel History',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelHistoryScreen(), // <-- const removed here
      ),
    );
  },
),
_buildSettingsTile(
  icon: Icons.outlined_flag,
  title: 'Report History',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>  UserReportHistoryPage()),
    );
  },
),

          // ABOUT
const SectionHeader(title: 'About'),
_buildSettingsTile(
  icon: Icons.description,
  title: 'Legalities of Transportation',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LegalitiesPage()),
    );
  },
),
_buildSettingsTile(
  icon: Icons.help_outline,
  title: 'Policies of all Transportations',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransportPoliciesPage()),
    );
  },
),
_buildSettingsTile(
  icon: Icons.info_outline,
  title: 'Terms and Policies of Developers',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeveloperPoliciesPage()),
    );
  },
),
const SectionHeader(title: ''),


_buildSettingsTile(
>>>>>>> Stashed changes
  icon: Icons.admin_panel_settings,
  title: 'Admin Mode (Not Accessible by Normal User/Guest)',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
<<<<<<< Updated upstream
        builder: (context) => const AdminScreen(),
=======
       builder: (context) => AdminScreen(), // removed `const`

>>>>>>> Stashed changes
      ),
    );
  },
),
<<<<<<< Updated upstream



          const SectionHeader(title: 'About'),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Legalities of transportations',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Policies of transportations',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'Terms and Policies of developers',
            onTap: () {},
=======
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
>>>>>>> Stashed changes
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(
          height: 5,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: Colors.black,
        ),
      ],
    );
  }
}
