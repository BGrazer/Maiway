// ↓↓↓ NEWLY ADDED BLOCK: SurveyPage.dart ↓↓↓

import 'package:flutter/material.dart';

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

  void _submitSurvey() {
    if (_fareFeedback == 'yes') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Nice!"),
          content: const Text("Thank you and have a safe trip."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen (main)
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

      // Simulate prediction logic
      final predictedFare = 12.0; // placeholder for actual algorithm
      final difference = (chargedFare - predictedFare).abs();
      final threshold = 5.0;

      final alert = (difference > threshold)
          ? "🚨 ALERT: Overpricing Detected!"
          : "✅ Fare is within the acceptable range.";

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Fare Validation Result"),
          content: Text(
            "Distance: ${widget.distanceKm} km\n"
            "Predicted Fare: ₱${predictedFare.toStringAsFixed(2)}\n"
            "Charged Fare: ₱${chargedFare.toStringAsFixed(2)}\n"
            "Difference: ₱${difference.toStringAsFixed(2)}\n\n"
            "$alert",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to main.dart
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Fare Survey"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("Was the fare given fair?", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Yes"),
                    value: 'yes',
                    groupValue: _fareFeedback,
                    onChanged: (value) {
                      setState(() {
                        _fareFeedback = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("No"),
                    value: 'no',
                    groupValue: _fareFeedback,
                    onChanged: (value) {
                      setState(() {
                        _fareFeedback = value;
                      });
                    },
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
                decoration: const InputDecoration(
                  hintText: "Enter fare in PHP",
                ),
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

// ↑↑↑ END OF SURVEY PAGE CODE ↑↑↑