import 'package:flutter/material.dart';

class LegalitiesPage extends StatelessWidget {
  const LegalitiesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legalities of Transportation')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'This page contains information about the legal frameworks governing public and private transportation systems.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
