import 'package:flutter/material.dart';

class DeveloperPoliciesPage extends StatelessWidget {
  const DeveloperPoliciesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Policies of Developers')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'This page describes the terms and privacy policies that developers follow in creating and maintaining this application.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
