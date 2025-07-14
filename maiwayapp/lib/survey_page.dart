import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyPage extends StatefulWidget {
  final double distanceKm;
  final String transportMode;
  final String passengerType;
  final String selectedPreference;

  const SurveyPage({
    super.key,
    required this.distanceKm,
    required this.transportMode,
    required this.passengerType,
    required this.selectedPreference,
  });

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  String? _fareFeedback;
  final TextEditingController _chargedFareController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  String? _selectedTransportMode;
  final List<String> _transportOptions = ['Jeep', 'Bus'];

  @override
  void initState() {
    super.initState();
    _selectedTransportMode = widget.transportMode;
    _distanceController.text = widget.distanceKm.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _chargedFareController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> pushSurveyToFirestore({
    required double distance,
    required String vehicleType,
    required String passengerType,
    required double fareGiven,
    required double predictedFare,
    required double difference,
    required bool isAnomalous,
    required String route,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("No user logged in.");
      return;
    }

    final userId = user.uid;
    final name = user.displayName ?? 'Anonymous';

    final surveyData = {
      'userId': userId,
      'name': name,
      'distance': distance.toString(),
      'vehicleType': vehicleType,
      'passenger_type': passengerType,
      'fare_given': fareGiven,
      'original_fare': predictedFare,
      'fare_difference': difference,
      'anomalous': isAnomalous,
      'route': route,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('surveys').add(surveyData);
  }

  bool isDiscountedPassenger(String passengerType) {
    final lower = passengerType.toLowerCase();
    return lower != 'regular';
  }

  Future<void> _submitSurvey() async {
    if (_fareFeedback == null || _selectedTransportMode == null || _distanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final distance = double.tryParse(_distanceController.text);
    if (distance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid distance input')),
      );
      return;
    }

    final discounted = isDiscountedPassenger(widget.passengerType);

    if (_fareFeedback == 'yes') {
      await pushSurveyToFirestore(
        distance: distance,
        vehicleType: _selectedTransportMode!,
        passengerType: widget.passengerType,
        fareGiven: 0.0,
        predictedFare: 0.0,
        difference: 0.0,
        isAnomalous: false,
        route: widget.selectedPreference,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Nice!"),
          content: Text(
            "Thank you and have a safe trip.\n\n"
            "Distance: $distance km\n"
            "Transport Mode: $_selectedTransportMode\n"
            "Passenger Type: ${widget.passengerType}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } else if (_fareFeedback == 'no') {
      if (_chargedFareController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the charged fare')),
        );
        return;
      }

      final chargedFare = double.tryParse(_chargedFareController.text);
      if (chargedFare == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid fare input')),
        );
        return;
      }

      final url = Uri.parse("http://127.0.0.1:5000/predict_fare");

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "vehicle_type": _selectedTransportMode,
            "passenger_type": widget.passengerType,
            "distance_km": distance,
            "charged_fare": chargedFare,
            "discounted": discounted, // ✅ REQUIRED BY BACKEND
          }),
        );

        final data = jsonDecode(response.body);

        if (data.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['error']}')),
          );
          return;
        }

        final predictedFare = double.tryParse(data['predicted_fare'].toString()) ?? 0.0;
        final difference = double.tryParse(data['difference'].toString()) ?? 0.0;
        final chargedFareFormatted = data['charged_fare'].toString();
        final isAnomalous = data['is_anomalous'] ?? false;

        await pushSurveyToFirestore(
          distance: distance,
          vehicleType: _selectedTransportMode!,
          passengerType: widget.passengerType,
          fareGiven: chargedFare,
          predictedFare: predictedFare,
          difference: difference,
          isAnomalous: isAnomalous,
          route: widget.selectedPreference,
        );

        final alert = isAnomalous
            ? "⚠️ ALERT: Overpricing Detected!"
            : "✅ Fare is within the acceptable range.";

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Fare Validation Result"),
            content: Text(
              "Distance: $distance km\n"
              "Predicted Fare: ₱$predictedFare\n"
              "Charged Fare: ₱$chargedFareFormatted\n"
              "Difference: ₱$difference\n\n"
              "$alert",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      } catch (e) {
        print("Error connecting to backend: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to server')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Fare Survey", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Distance (km)",
                hintText: "Enter estimated distance",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedTransportMode,
              decoration: const InputDecoration(labelText: "Vehicle Type"),
              items: _transportOptions.map((mode) {
                return DropdownMenuItem(value: mode, child: Text(mode));
              }).toList(),
              onChanged: (value) => setState(() => _selectedTransportMode = value),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text("Passenger Type: "),
                Text(widget.passengerType, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text("Route: "),
                Flexible(child: Text(widget.selectedPreference, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Do you feel you were charged the right amount?"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Yes"),
                    value: 'yes',
                    groupValue: _fareFeedback,
                    onChanged: (value) => setState(() => _fareFeedback = value),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("No"),
                    value: 'no',
                    groupValue: _fareFeedback,
                    onChanged: (value) => setState(() => _fareFeedback = value),
                  ),
                ),
              ],
            ),

            if (_fareFeedback == 'no') ...[
              const SizedBox(height: 20),
              const Text("How much was the charged fare?"),
              TextField(
                controller: _chargedFareController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: "Enter fare in PHP"),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitSurvey,
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
