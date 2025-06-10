import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'signup.dart';
import 'main.dart';
import 'forgot_password_page.dart';
class LoginPage extends StatelessWidget {
  final Color backgroundColor = Color(0xFF3F7399);
  final Color textBoxColor = Color(0xFF292929);
  final Color buttonColor = Color(0xFFBFCBCE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              SizedBox(height: 80),
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
                'Please Login To Your Account',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              Spacer(),
              //Enter Email
              _customTextField(label: 'Enter Your Email', icon: Icons.email),
              SizedBox(height: 16),
              //Enter Password
              _customTextField(
                label: 'Enter Your Password',
                icon: Icons.lock,
                obscure: true,
              ),
              //Alignment for Forgot Pass
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                  Navigator.push(
                   context,
                    MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                      );
                     },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              // Redirect to home screen of app
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomeNavigation()),
                  );
                },
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
              // Sign Up
              RichText(
                text: TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: 'Sign Up',
                      style: TextStyle(color: Colors.blue),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SignupPage()),
                              );
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
