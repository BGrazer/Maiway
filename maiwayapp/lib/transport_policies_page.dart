import 'package:flutter/material.dart';

class TransportPoliciesPage extends StatelessWidget {
  const TransportPoliciesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policies of All Transportations')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'This page outlines the general policies followed by different modes of transportation such as jeepneys, buses, LRTs, and tricycles.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
