import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'main.dart';

class SignupPage extends StatelessWidget {
  final Color backgroundColor = Color(0xFF3F7399);
  final Color textBoxColor = Color(0xFF292929);
  final Color buttonColor = Color(0xFFBFCBCE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'MAIWAY',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please Sign Up Your Account',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 40),
                  //Enter Name
                  _customTextField(
                    label: 'Enter Your Name',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 16),
                  //Enter Email
                  _customTextField(
                    label: 'Enter Your Email',
                    icon: Icons.email,
                  ),
                  SizedBox(height: 16),
                  //Enter Password
                  _customTextField(
                    label: 'Enter Your Password',
                    icon: Icons.lock,
                    obscure: true,
                  ),
                  SizedBox(height: 16),
                  //Confirm Password
                  _customTextField(
                    label: 'Confirm Password',
                    icon: Icons.lock,
                    obscure: true,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => MyApp()),
                      );
                    },
                    child: Text('Create Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Redirect to Login
                  RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(color: Colors.blue),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pop(context);
                                },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //For the texts
  Widget _customTextField({
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      width: double.infinity,
      child: TextField(
        obscureText: obscure,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: textBoxColor,
          prefixIcon: Icon(icon, color: Colors.white),
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}
