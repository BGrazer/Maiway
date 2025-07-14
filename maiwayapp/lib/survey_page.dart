import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyPage extends StatefulWidget {
  final List<Map<String, dynamic>> rides;
  final String passengerType;

  const SurveyPage({
    super.key,
    required this.rides,
    required this.passengerType,
  });

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final List<String?> _fareFeedbacks = [];
  final List<TextEditingController> _chargedFareControllers = [];

  @override
  void initState() {
    super.initState();
    _fareFeedbacks.addAll(List.filled(widget.rides.length, null));
    _chargedFareControllers.addAll(List.generate(widget.rides.length, (_) => TextEditingController()));
  }

  @override
  void dispose() {
    for (var controller in _chargedFareControllers) {
      controller.dispose();
    }
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
    if (user == null) return;

    final surveyData = {
      'userId': user.uid,
      'name': user.displayName ?? 'Anonymous',
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

  Future<void> _submitSurvey() async {
    for (int i = 0; i < widget.rides.length; i++) {
      final ride = widget.rides[i];
      final feedback = _fareFeedbacks[i];

      if (feedback == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please answer fare question for Ride ${i + 1}")),
        );
        return;
      }

      final distance = ride['distanceKm'];
      final vehicleType = ride['vehicleType'];
      final route = ride['route'];

      if (feedback == 'yes') {
        await pushSurveyToFirestore(
          distance: distance,
          vehicleType: vehicleType,
          passengerType: widget.passengerType,
          fareGiven: 0.0,
          predictedFare: 0.0,
          difference: 0.0,
          isAnomalous: false,
          route: route,
        );
      } else {
        final fareText = _chargedFareControllers[i].text.trim();
        if (fareText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Please enter fare for Ride ${i + 1}")),
          );
          return;
        }

        final chargedFare = double.tryParse(fareText);
        if (chargedFare == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid fare input for Ride ${i + 1}")),
          );
          return;
        }

        try {
          final response = await http.post(
            Uri.parse("http://127.0.0.1:5000/predict_fare"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "vehicle_type": vehicleType,
              "passenger_type": widget.passengerType,
              "distance_km": distance,
              "charged_fare": chargedFare,
            }),
          );

          final data = jsonDecode(response.body);

          if (data.containsKey('error')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: ${data['error']}")),
            );
            return;
          }

          final predictedFare = data['predicted_fare'].toDouble();
          final difference = data['difference'].toDouble();
          final isAnomalous = chargedFare > predictedFare;

          await pushSurveyToFirestore(
            distance: distance,
            vehicleType: vehicleType,
            passengerType: widget.passengerType,
            fareGiven: chargedFare,
            predictedFare: predictedFare,
            difference: difference,
            isAnomalous: isAnomalous,
            route: route,
          );

          String alert;
          if (chargedFare > predictedFare) {
            alert = "⚠️ ALERT: Overpricing Detected!";
          } else if (chargedFare < predictedFare) {
            alert = "✅ Fare is fair.\n\nNote: The charged fare is lower than expected.\nThe correct fare should be ₱${predictedFare.toStringAsFixed(2)}";
          } else {
            alert = "✅ Fare is within the acceptable range.";
          }

          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Ride ${i + 1} Result"),
              content: Text(
                "Distance: ${distance.toStringAsFixed(2)} km\n"
                "Vehicle: $vehicleType\n"
                "Route: $route\n\n"
                "Predicted Fare: ₱${predictedFare.toStringAsFixed(2)}\n"
                "Charged Fare: ₱${chargedFare.toStringAsFixed(2)}\n"
                "Difference: ₱${difference.toStringAsFixed(2)}\n\n"
                "$alert",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Continue"),
                )
              ],
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect to server')),
          );
          return;
        }
      }
    }

    // All rides complete
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("All Rides Submitted"),
        content: const Text("Thank you! Your survey has been submitted."),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fare Survey")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          children: [
            for (int i = 0; i < widget.rides.length; i++) ...[
              Text("Ride ${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Vehicle: ${widget.rides[i]['vehicleType']}"),
              Text("Distance: ${widget.rides[i]['distanceKm'].toStringAsFixed(2)} km"),
              Text("Route: ${widget.rides[i]['route']}"),
              const SizedBox(height: 10),
              const Text("Do you feel you were charged the right amount?"),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text("Yes"),
                      value: 'yes',
                      groupValue: _fareFeedbacks[i],
                      onChanged: (val) {
                        setState(() => _fareFeedbacks[i] = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text("No"),
                      value: 'no',
                      groupValue: _fareFeedbacks[i],
                      onChanged: (val) {
                        setState(() => _fareFeedbacks[i] = val);
                      },
                    ),
                  ),
                ],
              ),
              if (_fareFeedbacks[i] == 'no') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _chargedFareControllers[i],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Charged Fare (₱)",
                    hintText: "Enter charged fare",
                  ),
                ),
              ],
              const Divider(height: 30),
            ],
            ElevatedButton(
              onPressed: _submitSurvey,
              child: const Text("Submit Survey"),
            )
          ],
        ),
      ),
    );
  }
}