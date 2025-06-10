// lib/edit_profile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {

  final _formKey = GlobalKey<FormState>();

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
          child: Form( 
            key: _formKey, 
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
                _buildTextFormField(
                  controller: _nameController,
                  labelText: 'Name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _buildTextFormField(
                  controller: _emailController,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email cannot be empty';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                       return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _buildTextFormField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number cannot be empty';
                    }
                    if (value.length < 7) {
                      return 'Phone number too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _showUpdateConfirmationDialog(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all required fields.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
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
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              border: InputBorder.none, 
              errorStyle: TextStyle(fontSize: 0.1, height: 0), 
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Builder(
          builder: (context) {
            final FormFieldState<String>? fieldState = context.findAncestorStateOfType<FormFieldState<String>>();
            if (fieldState != null && fieldState.hasError) {
              return Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                child: Text(
                  fieldState.errorText ?? 'Invalid input',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              );
            }
            return const SizedBox.shrink(); 
          },
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