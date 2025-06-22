import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void dispose() {
    _chargedFareController.dispose();
    super.dispose();
  }

  String mapVehicleType(String frontendType) {
    switch (frontendType) {
      case "Jeepney":
        return "Jeep";
      case "LRT1":
        return "LRT 1";
      default:
        return frontendType;
    }
  }

  Future<void> _submitSurvey() async {
    if (_fareFeedback == 'yes') {
      if (!mounted) return;
      _showDialog("Nice!", "Thank you and have a safe trip.");
    } else if (_fareFeedback == 'no') {
      if (_chargedFareController.text.isEmpty) {
        if (!mounted) return;
        _showSnackbar('Please enter the charged fare');
        return;
      }

      final chargedFare = double.tryParse(_chargedFareController.text);
      if (chargedFare == null) {
        if (!mounted) return;
        _showSnackbar('Invalid fare input');
        return;
      }

      final result = await _validateFareWithBackend(
        vehicleType: mapVehicleType(widget.transportMode),
        distanceKm: widget.distanceKm,
        chargedFare: chargedFare,
        isDiscounted: widget.passengerType == 'Discounted',
      );

      if (result == null) {
        if (!mounted) return;
        _showSnackbar('Server error or no response.');
        return;
      }

      final alertMessage = result['is_anomalous']
          ? "ALERT: Overpricing Detected!"
          : "Fare is within the acceptable range.";

      if (!mounted) return;
      _showDialog(
        "Fare Validation Result",
        "Distance: ${widget.distanceKm} km\n"
        "Predicted Fare: ₱${result['predicted_fare']}\n"
        "Charged Fare: ₱${result['charged_fare']}\n"
        "Difference: ₱${result['difference']}\n"
        "Threshold: ₱${result['threshold']}\n\n"
        "$alertMessage",
      );
    }
  }

  Future<Map<String, dynamic>?> _validateFareWithBackend({
    required String vehicleType,
    required double distanceKm,
    required double chargedFare,
    required bool isDiscounted,
  }) async {
    const String backendUrl = 'http://localhost:49945/predict_fare';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicle_type': vehicleType,
          'distance_km': distanceKm,
          'charged_fare': chargedFare,
          'discounted': isDiscounted,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Backend error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print("Error calling backend: $e");
      return null;
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDialog(String title, String content) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to map
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
      appBar: AppBar(
        title: const Text("Trip Fare Survey"),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selected Travel Preferences:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("• Preference: ${widget.selectedPreference}"),
                    Text("• Mode: ${widget.transportMode}"),
                    Text("• Passenger Type: ${widget.passengerType}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Was the fare given fair?", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
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
            const Spacer(),
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
