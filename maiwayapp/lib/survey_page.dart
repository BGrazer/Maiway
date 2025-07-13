import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ For Firebase

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
  String? _selectedTransportMode;
  final TextEditingController _chargedFareController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _routeController =
      TextEditingController(); // ✅ New Route Field

  final List<String> _transportOptions = ['Jeep', 'Bus', 'LRT-1', 'Tricycle'];

  @override
  void dispose() {
    _chargedFareController.dispose();
    _distanceController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  // ✅ PUSH TO FIREBASE FUNCTION
  Future<void> _saveToFirebase({
    required double distance,
    required String transportMode,
    required String passengerType,
    required String preference,
    required String route,
    required String fareFeedback,
    double? chargedFare,
    bool? isAnomalous,
    double? predictedFare,
  }) async {
    await FirebaseFirestore.instance.collection('fare_reports').add({
      'timestamp': Timestamp.now(),
      'distance_km': distance,
      'vehicle_type': transportMode,
      'passenger_type': passengerType,
      'selected_preference': preference,
      'route': route,
      'fare_feedback': fareFeedback,
      'charged_fare': chargedFare,
      'predicted_fare': predictedFare,
      'is_anomalous': isAnomalous,
    });
  }

  Future<void> _submitSurvey() async {
    if (_fareFeedback == null ||
        _selectedTransportMode == null ||
        _distanceController.text.isEmpty ||
        _routeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final distance = double.tryParse(_distanceController.text);
    if (distance == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid distance input')));
      return;
    }

    final routeTaken = _routeController.text;

    if (_fareFeedback == 'yes') {
      // ✅ Store to Firebase even for YES feedback
      await _saveToFirebase(
        distance: distance,
        transportMode: _selectedTransportMode!,
        passengerType: widget.passengerType,
        preference: widget.selectedPreference,
        route: routeTaken,
        fareFeedback: 'yes',
      );

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Thank you!"),
              content: Text(
                "distanceKm: $distance km\n"
                "transportMode: $_selectedTransportMode\n"
                "Passenger Type: ${widget.passengerType}",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid fare input')));
        return;
      }

      final url = Uri.parse("http://192.168.254.124:49945/predict_fare");
      final isDiscounted = widget.passengerType.toLowerCase() == 'discounted';

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "vehicle_type": _selectedTransportMode,
            "distance_km": distance,
            "charged_fare": chargedFare,
            "discounted": isDiscounted,
          }),
        );

        final data = jsonDecode(response.body);
        final predictedFare = data['predicted_fare'];
        final difference = data['difference'];
        final chargedFareFormatted = data['charged_fare'];
        final isAnomalous = data['is_anomalous'];

        // ✅ Store to Firebase even for anomalous/no
        await _saveToFirebase(
          distance: distance,
          transportMode: _selectedTransportMode!,
          passengerType: widget.passengerType,
          preference: widget.selectedPreference,
          route: routeTaken,
          fareFeedback: 'no',
          chargedFare: chargedFare,
          predictedFare: predictedFare,
          isAnomalous: isAnomalous,
        );

        final alert =
            isAnomalous
                ? "ALERT: Overpricing Detected!"
                : "Fare is within the acceptable range.";

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
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
                  ),
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
            const Text(
              "Fare Survey",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ✅ Route Taken Input
            TextField(
              controller: _routeController,
              decoration: const InputDecoration(
                labelText: "Route Taken",
                hintText: "Enter your route (e.g., España to Monumento)",
              ),
            ),

            const SizedBox(height: 12),

            // Distance input
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Distance (km)",
                hintText: "Enter estimated distance",
              ),
            ),

            const SizedBox(height: 12),

            // Vehicle dropdown
            DropdownButtonFormField<String>(
              value: _selectedTransportMode,
              decoration: const InputDecoration(labelText: "Vehicle Type"),
              items:
                  _transportOptions.map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode));
                  }).toList(),
              onChanged:
                  (value) => setState(() => _selectedTransportMode = value),
            ),

            const SizedBox(height: 12),

            // Passenger Type (display only)
            Row(
              children: [
                const Text("Passenger Type: "),
                Text(
                  widget.passengerType,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: "Enter fare in PHP",
                ),
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
