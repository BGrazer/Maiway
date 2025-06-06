import 'package:flutter/material.dart';
import 'change_pass.dart';
import 'user_report_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Account'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () {},
          ),
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
          _buildSettingsTile(
            icon: Icons.place,
            title: 'Travel History',
            onTap: () {},
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
            icon: Icons.admin_panel_settings,
            title: 'Admin Mode (Not Accessible by Normal User/Guest)',
            onTap: () {},
          ),

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
