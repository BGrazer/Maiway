import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Support and About'),
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
          _buildSettingsTile(
            icon: Icons.https,
            title: 'Privacy policies',
            onTap: () {},
          ),

          const SectionHeader(title: 'Cache & Cellular'),
          _buildSettingsTile(
            icon: Icons.delete,
            title: 'Free Up Space',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.signal_cellular_alt,
            title: 'Data Saver',
            onTap: () {},
          ),

          const SectionHeader(title: 'Actions'),
          _buildSettingsTile(
            icon: Icons.outlined_flag,
            title: 'Report a Bug',
            onTap: () {},
          ),
          _buildSettingsTile(icon: Icons.logout, title: 'Logout', onTap: () {}),
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
