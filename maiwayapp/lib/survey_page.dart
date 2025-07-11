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

  Future<void> _submitSurvey() async {
    if (_fareFeedback == 'yes') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Nice!"),
          content: Text(
            "Thank you and have a safe trip.\n\n"
            "Distance: ${widget.distanceKm} km\n"
            "Transport Mode: ${widget.transportMode}\n"
            "Passenger Type: ${widget.passengerType}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close bottom sheet
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

   
      // Replace with your actual backend URL every time you use different network
      final url = Uri.parse("http://192.168.254.105:49945/predict_fare");
      final isDiscounted = widget.passengerType.toLowerCase() == 'discounted';

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "vehicle_type": widget.transportMode,
            "distance_km": widget.distanceKm,
            "charged_fare": chargedFare,
            "discounted": isDiscounted,
          }),
        );

        final data = jsonDecode(response.body);
        final predictedFare = data['predicted_fare'];
        final difference = data['difference'];
        final chargedFareFormatted = data['charged_fare'];
        final isAnomalous = data['is_anomalous'];

        final alert = isAnomalous
            ? " ALERT: Overpricing Detected!"
            : " Fare is within the acceptable range.";

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Fare Validation Result"),
            content: Text(
              "Distance: ${widget.distanceKm} km\n"
              "Predicted Fare: ₱$predictedFare\n"
              "Charged Fare: ₱$chargedFareFormatted\n"
              "Difference: ₱$difference\n\n"
              "$alert",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // bottom sheet
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Do you feel you were charged the right amount?",
              style: TextStyle(fontSize: 18)),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: "Enter fare in PHP"),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitSurvey,
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}
