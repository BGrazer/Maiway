import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:maiwayapp/models/route_segment.dart';
import 'package:maiwayapp/services/routing_service.dart';
import 'package:google_fonts/google_fonts.dart';

/// One step in a step-by-step fare survey (Jeep or Bus only; used with RFR /predict_fare backend).
/// Route = leg you took (e.g. Manila City Hall to Padre Faura).
/// Route name of vehicle = bus/jeep route name in parentheses (e.g. Biñan - Plaza Lawton).
class SurveyStep {
  final String routeLeg;           // Route you took: fromStop to toStop
  final String routeNameOfVehicle; // Route name of vehicle (e.g. Biñan - Plaza Lawton)
  final double distanceKm;
  final String vehicleType;        // Jeep or Bus only (RFR backend)

  SurveyStep({
    required this.routeLeg,
    required this.routeNameOfVehicle,
    required this.distanceKm,
    required this.vehicleType,
  });
}

class SurveyPage extends StatefulWidget {
  final String passengerType;
  /// When provided (e.g. from End Trip), survey is pre-filled and step-by-step by segment.
  final List<RouteSegment>? tripSegments;

  const SurveyPage({
    super.key,
    required this.passengerType,
    this.tripSegments,
  });

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  late List<SurveyStep> _steps;
  int _currentStepIndex = 0;
  final List<String?> _fareFeedback = []; // 'yes' | 'no' per step
  final List<TextEditingController> _chargedFareControllers = [];

  List<String> predefinedRoutes = [];

  @override
  void initState() {
    super.initState();
    _buildSteps();
  }

  void _buildSteps() {
    if (widget.tripSegments != null && widget.tripSegments!.isNotEmpty) {
      // Only Jeep and Bus segments (survey + predict_fare are connected to RFR backend, which has Jeep/Bus models only)
      final transportSegments = widget.tripSegments!
          .where((s) {
            final m = s.mode.name.toLowerCase();
            return m == 'jeep' || m == 'jeepney' || m == 'bus';
          })
          .toList();
      if (transportSegments.isEmpty) {
        _steps = [];
      } else {
        _steps = transportSegments.map((seg) {
          final modeName = seg.mode.name.toLowerCase();
          final vehicle = (modeName == 'bus') ? 'Bus' : 'Jeep';
          // Route name of vehicle = bus/jeep route name from GeoJSON (e.g. Biñan - Plaza Lawton)
          final routeNameOfVehicle = (seg.name.trim().isNotEmpty && seg.name != 'Unnamed Segment')
              ? _sanitizeLocationName(seg.name)
              : '—';
          // Route you took = leg from stop to stop (e.g. Manila City Hall to Padre Faura)
          String routeLeg = _sanitizeLocationName('${seg.fromStop} to ${seg.toStop}');
          if (routeLeg.isEmpty || routeLeg.contains('.geojson') || routeLeg == routeNameOfVehicle) {
            routeLeg = 'Segment start to Segment end';
          }
          // Backend usually sends segment distance in km; if > 100 assume meters
          final distanceKm = seg.distance >= 0
              ? (seg.distance > 100 ? seg.distance / 1000.0 : seg.distance)
              : 0.0;
          return SurveyStep(
            routeLeg: routeLeg,
            routeNameOfVehicle: routeNameOfVehicle,
            distanceKm: distanceKm,
            vehicleType: vehicle,
          );
        }).toList();
        for (var i = 0; i < _steps.length; i++) {
          _fareFeedback.add(null);
          _chargedFareControllers.add(TextEditingController());
        }
      }
    } else {
      _steps = [
        SurveyStep(routeLeg: '', routeNameOfVehicle: '—', distanceKm: 0.0, vehicleType: 'Jeep'),
      ];
      _fareFeedback.add(null);
      _chargedFareControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _chargedFareControllers) {
      c.dispose();
    }
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
    String? routeLeg,
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
      if (routeLeg != null && routeLeg.isNotEmpty) 'route_leg': routeLeg,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('surveys').add(surveyData);
  }

  /// Replace "unknown location" with a fallback so we always show a name.
  static String _sanitizeLocationName(String name) {
    if (name.trim().isEmpty) return 'Current location';
    final lower = name.toLowerCase();
    if (lower.contains('unknown location')) {
      return name.replaceAll(RegExp(r'unknown\s*location', caseSensitive: false), 'Current location').trim();
    }
    return name.trim();
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  SurveyStep get _currentStep => _steps[_currentStepIndex];

  Future<void> _submitCurrentStep() async {
    final feedback = _fareFeedback[_currentStepIndex];
    if (feedback == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer: were you charged the right amount?')),
      );
      return;
    }

    final step = _currentStep;
    final distance = step.distanceKm;
    // Save route name of vehicle for Admin Reports (second field in survey), not the route leg
    final routeForReports = step.routeNameOfVehicle;
    final routeLeg = step.routeLeg;
    final vehicleType = step.vehicleType;
    final passengerType = widget.passengerType;
    final isDiscounted = passengerType.toLowerCase() == 'discounted';

    double chargedFare = 0.0;
    if (feedback == 'no') {
      final controller = _chargedFareControllers[_currentStepIndex];
      if (controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the charged fare')),
        );
        return;
      }
      chargedFare = double.tryParse(controller.text.trim()) ?? 0.0;
      if (chargedFare <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid fare')),
        );
        return;
      }
    }

    if (feedback == 'yes') {
      await pushSurveyToFirestore(
        distance: distance,
        vehicleType: vehicleType,
        passengerType: passengerType,
        fareGiven: 0.0,
        predictedFare: 0.0,
        difference: 0.0,
        isAnomalous: false,
        route: routeForReports,
        routeLeg: routeLeg,
      );
      if (mounted) _showThankYou(route: routeForReports, distance: distance, vehicleType: vehicleType, fare: 0.0);
      return;
    }

    if (feedback == 'no') {
      // Try local RFR (port 5002) first when running py main.py; fallback to production
      final urls = [
        Uri.parse('${RoutingService.rfrBaseUrl}/predict_fare'),
        Uri.parse('https://maiway-backend-production.up.railway.app/predict_fare'),
      ];
      http.Response? response;
      for (final url in urls) {
        try {
          response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'vehicle_type': vehicleType,
                  'passenger_type': passengerType,
                  'distance_km': distance,
                  'charged_fare': chargedFare,
                  'discounted': isDiscounted,
                }),
              )
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) break;
        } catch (_) {
          response = null;
          continue;
        }
      }
      if (response == null || response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to connect to server. Make sure the RFR backend is running (py main.py starts it on port 5002).',
              ),
            ),
          );
        }
        return;
      }
      try {
        final data = jsonDecode(response.body);
        final predictedFare = data['predicted_fare'].toDouble();
        final difference = data['difference'].toDouble();
        final isAnomalous = data['is_anomalous'] ?? false;

        await pushSurveyToFirestore(
          distance: distance,
          vehicleType: vehicleType,
          passengerType: passengerType,
          fareGiven: chargedFare,
          predictedFare: predictedFare,
          difference: difference,
          isAnomalous: isAnomalous,
          route: routeForReports,
          routeLeg: routeLeg,
        );

        final roundedCharged = smartRound(chargedFare);
        final roundedPredicted = smartRound(predictedFare);
        final roundedDiff = smartRound(difference);
        String alert;
        if (roundedCharged == roundedPredicted) {
          alert = 'Fare is just right.';
        } else if (roundedCharged < roundedPredicted) {
          alert = 'You saved ₱${roundedDiff.toStringAsFixed(2)}. Original fare ₱${roundedPredicted.toStringAsFixed(2)}.';
        } else {
          alert = 'ALERT: Overpricing detected.';
        }
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Fare validation'),
              content: Text(
                'Route: $routeForReports\n'
                'Distance: $distance km\n'
                'Predicted: ₱${roundedPredicted.toStringAsFixed(2)}\n'
                'Charged: ₱${roundedCharged.toStringAsFixed(2)}\n'
                'Difference: ₱${roundedDiff.toStringAsFixed(2)}\n\n$alert',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _advanceOrFinish();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showThankYou({required String route, required double distance, required String vehicleType, required double fare}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thank you!'),
        content: Text(
          'Your response has been recorded.\n\n'
          'Route: $route\n'
          'Distance: $distance km\n'
          'Vehicle: $vehicleType\n'
          'Passenger: ${widget.passengerType}\n'
          'Fare: ₱${smartRound(fare).toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _advanceOrFinish();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _advanceOrFinish() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Fare Survey'),
          backgroundColor: const Color(0xFF6699CC),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No jeep or bus segments to survey.'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    final step = _currentStep;
    final isMultiStep = _steps.length > 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(isMultiStep ? 'Fare Survey (${_currentStepIndex + 1} of ${_steps.length})' : 'Fare Survey'),
        backgroundColor: const Color(0xFF6699CC),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Route you took (e.g. Manila City Hall to Padre Faura)
                    _sectionLabel('Route you took'),
                    const SizedBox(height: 6),
                    _readOnlyChip(step.routeLeg.isEmpty ? '—' : step.routeLeg),
                    const SizedBox(height: 16),

                    // Route name of vehicle (e.g. Biñan - Plaza Lawton) — the part in parentheses
                    _sectionLabel('Route name of vehicle'),
                    const SizedBox(height: 6),
                    _readOnlyChip(step.routeNameOfVehicle),
                    const SizedBox(height: 16),

                    // Distance
                    _sectionLabel('Distance'),
                    const SizedBox(height: 6),
                    _readOnlyChip('${step.distanceKm.toStringAsFixed(2)} km'),
                    const SizedBox(height: 16),

                    // Vehicle type (Bus/Jeep)
                    _sectionLabel('Vehicle type'),
                    const SizedBox(height: 6),
                    _readOnlyChip(step.vehicleType),
                    const SizedBox(height: 16),

                    // Passenger type
                    _sectionLabel('Passenger type'),
                    const SizedBox(height: 6),
                    _readOnlyChip(widget.passengerType),
                    const SizedBox(height: 24),

                    // Yes / No
                    _sectionLabel('Do you feel you were charged the right amount?'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Yes'),
                            value: 'yes',
                            groupValue: _fareFeedback[_currentStepIndex],
                            onChanged: (value) => setState(() => _fareFeedback[_currentStepIndex] = value),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('No'),
                            value: 'no',
                            groupValue: _fareFeedback[_currentStepIndex],
                            onChanged: (value) => setState(() => _fareFeedback[_currentStepIndex] = value),
                          ),
                        ),
                      ],
                    ),
                    if (_fareFeedback[_currentStepIndex] == 'no') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _chargedFareControllers[_currentStepIndex],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Charged fare (₱)',
                          hintText: 'Enter amount in PHP',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitCurrentStep,
                  icon: const Icon(Icons.check),
                  label: Text(_currentStepIndex < _steps.length - 1 ? 'Submit & Next' : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6699CC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _readOnlyChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
