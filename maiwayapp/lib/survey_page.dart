import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'
    show rootBundle, FilteringTextInputFormatter;

class SurveyPage extends StatefulWidget {
  final String transportMode;
  final String passengerType;

  const SurveyPage({
    super.key,
    required this.transportMode,
    required this.passengerType,
  });

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  String? _fareFeedback;
  String? _selectedVehicleType;
  final TextEditingController _chargedFareController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();

  List<String> predefinedRoutes = [];

  @override
  void initState() {
    super.initState();
    _distanceController.text = "0.0";
    _selectedVehicleType = widget.transportMode;
    loadRoutesFromJson();
  }

  Future<void> loadRoutesFromJson() async {
    final String response = await rootBundle.loadString(
      'assets/Jeep_routes.json',
    );
    final data = json.decode(response);
    setState(() {
      predefinedRoutes = List<String>.from(
        data['RoutedJeeps'].map((item) => item['route']),
      );
    });
  }

  @override
  void dispose() {
    _chargedFareController.dispose();
    _distanceController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  double smartRound(double value) {
    final decimal = value - value.floor();
    return decimal >= 0.5 ? value.ceilToDouble() : value.floorToDouble();
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
      'fare_given': smartRound(fareGiven),
      'original_fare': smartRound(predictedFare),
      'fare_difference': smartRound(difference),
      'anomalous': isAnomalous,
      'route': route,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('surveys').add(surveyData);
  }

  Future<void> _submitSurvey() async {
    if (_fareFeedback == null ||
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

    final route = _routeController.text.trim();
    final vehicleType = _selectedVehicleType ?? widget.transportMode;
    final passengerType = widget.passengerType;
    final isDiscounted = passengerType.toLowerCase() == 'discounted';

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

    if (_fareFeedback == 'yes') {
      await pushSurveyToFirestore(
        distance: distance,
        vehicleType: vehicleType,
        passengerType: passengerType,
        fareGiven: chargedFare,
        predictedFare: chargedFare, // assumed to be correct
        difference: 0.0,
        isAnomalous: false,
        route: route,
      );

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Thank you!"),
              content: Text(
                "Your response has been recorded.\n\n"
                "Route: $route\n"
                "Distance: $distance km\n"
                "Vehicle: $vehicleType\n"
                "Passenger Type: $passengerType\n"
                "Fare: ₱${smartRound(chargedFare).toStringAsFixed(2)}",
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
      final url = Uri.parse(
        "https://maiway-backend-production.up.railway.app/predict_fare",
      );

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "vehicle_type": vehicleType,
            "passenger_type": passengerType,
            "distance_km": distance,
            "charged_fare": chargedFare,
            "discounted": isDiscounted,
          }),
        );

        final data = jsonDecode(response.body);
        final predictedFare = data['predicted_fare'].toDouble();
        final difference = data['difference'].toDouble();
        final isAnomalous = data['is_anomalous'] ?? false;

        final roundedChargedFare = smartRound(chargedFare);
        final roundedPredictedFare = smartRound(predictedFare);
        final roundedDifference = smartRound(difference);

        String alert;
        if (roundedChargedFare == roundedPredictedFare) {
          alert = " Fare is just right.";
        } else if (roundedChargedFare < roundedPredictedFare) {
          alert =
              " You have saved ₱${roundedDifference.toStringAsFixed(2)}.\nThe original fare is ₱${roundedPredictedFare.toStringAsFixed(2)}.";
        } else {
          alert = " ALERT: Overpricing Detected!";
        }

        await pushSurveyToFirestore(
          distance: distance,
          vehicleType: vehicleType,
          passengerType: passengerType,
          fareGiven: chargedFare,
          predictedFare: predictedFare,
          difference: difference,
          isAnomalous: isAnomalous,
          route: route,
        );

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Fare Validation Result"),
                content: Text(
                  "Route: $route\n"
                  "Distance: $distance km\n"
                  "Predicted Fare: ₱${roundedPredictedFare.toStringAsFixed(2)}\n"
                  "Charged Fare: ₱${roundedChargedFare.toStringAsFixed(2)}\n"
                  "Difference: ₱${roundedDifference.toStringAsFixed(2)}\n\n"
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

            RawAutocomplete<String>(
              textEditingController: _routeController,
              focusNode: FocusNode(),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return predefinedRoutes.where(
                  (route) => route.toLowerCase().startsWith(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Route",
                    hintText: "Type or select a route",
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: "Distance (km)",
                hintText: "Enter estimated distance",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedVehicleType,
              items:
                  ['Jeep', 'Bus']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _selectedVehicleType = value),
              decoration: const InputDecoration(labelText: "Vehicle Type"),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Text(
                  "Passenger Type: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(widget.passengerType),
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

            if (_fareFeedback == 'yes' || _fareFeedback == 'no') ...[
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
