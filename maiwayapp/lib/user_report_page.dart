import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _dateController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _detailsController = TextEditingController();

  String? _vehicleType;
  String? _complaintType;
  bool _contactReadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data() ?? {};

      _fullNameController.text = data['name'] ?? '';

      final contact = (data['contactNumber'] ?? '') as String;
      if (contact.startsWith('+63')) {
        _contactController.text = contact.substring(3);
        _contactReadOnly = true;
      }
      setState(() {});
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    labelStyle: const TextStyle(color: Colors.blue),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.blue),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.blue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );

  Widget _contactInput() {
    return TextFormField(
      controller: _contactController,
      keyboardType: TextInputType.phone,
      readOnly: _contactReadOnly,
      decoration: _dec('Contact Number').copyWith(
        prefixText: '+63 ',
        prefixStyle: const TextStyle(color: Colors.black),
      ),
      validator: (value) {
        if (_contactReadOnly) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Please enter contact number';
        }
        if (!RegExp(r'^9\d{9}$').hasMatch(value.trim())) {
          return 'Enter PH number e.g. 9123456789';
        }
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final contactNumber = '+63${_contactController.text.trim()}';
    final formattedDateString = _dateController.text;

    final report = {
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'contactNumber': contactNumber,
      'date': formattedDateString,
      'vehicleType': _vehicleType,
      'plateNumber': _plateNumberController.text.trim(),
      'typeOfComplaint': _complaintType,
      'details': _detailsController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Pending',
    };

    try {
      await FirebaseFirestore.instance.collection('reports').add(report);

      if (!_contactReadOnly) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'contactNumber': contactNumber,
          });
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Report'),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: _dec('Full Name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Full name required';
                  }

                  final parts = v.trim().split(RegExp(r'\s+'));
                  if (parts.length < 2) {
                    return 'Please enter both first and last name';
                  }

                  final nameRegex = RegExp(r'^[a-zA-Z\s.]+$');
                  if (!nameRegex.hasMatch(v.trim())) {
                    return 'Name should not have numbers or symbols.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: _dec('Email'),
              ),
              const SizedBox(height: 20),
              _contactInput(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: _dec('Date'),
                validator:
                    (v) => v == null || v.isEmpty ? 'Select a date' : null,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateController.text =
                          '${pickedDate.month}/${pickedDate.day}/${pickedDate.year}';
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: _dec('Vehicle Type'),
                items: const [
                  DropdownMenuItem(value: 'Jeepney', child: Text('Jeepney')),
                  DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                ],
                onChanged: (v) => setState(() => _vehicleType = v),
                validator: (v) => v == null ? 'Select vehicle type' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _plateNumberController,
                decoration: _dec('Plate Number'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter plate number';
                  }

                  final plateRegex = RegExp(r'^[a-zA-Z0-9]+$');
                  if (!plateRegex.hasMatch(v.trim())) {
                    return 'Plate number should only contain letters and numbers.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _complaintType,
                decoration: _dec('Type of Complaint'),
                items: const [
                  DropdownMenuItem(value: 'Safety', child: Text('Safety')),
                  DropdownMenuItem(
                    value: 'Hearing',
                    child: Text('Hearing (Pagdinig sa Kaso)'),
                  ),
                  DropdownMenuItem(
                    value: 'Others',
                    child: Text('Iba pang Bagay'),
                  ),
                ],
                onChanged: (v) => setState(() => _complaintType = v),
                validator: (v) => v == null ? 'Select complaint type' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _detailsController,
                maxLines: 5,
                decoration: _dec('Complaint Details'),
                validator:
                    (v) => v == null || v.isEmpty ? 'Enter details' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF457B9D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
