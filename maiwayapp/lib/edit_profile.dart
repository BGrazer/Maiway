// lib/edit_profile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Jhon');
  final TextEditingController _emailController = TextEditingController(text: 'Jhon2490@xyz.com');
  final TextEditingController _phoneController = TextEditingController(text: '+91 9898989898');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF4C7B8D),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/profile_pic.png'), 
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        print('Change profile picture tapped');
                      },
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFFFFFFFF),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Change profile',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 16, color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 30),

              _buildTextField(
                controller: _nameController,
                labelText: 'Name',
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _phoneController,
                labelText: 'Phone',
                keyboardType: TextInputType.phone, 
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly 
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showUpdateConfirmationDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C7B8D),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Update Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters, 
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
          child: Text(
            labelText,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters, 
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _showUpdateConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Update'),
          content: const Text('Are you sure you want to update your profile?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); 

                print('Name: ${_nameController.text}');
                print('Email: ${_emailController.text}');
                print('Phone: ${_phoneController.text}');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your profile has been successfully updated!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2), 
                  ),
                );

              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }
}