import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  // Theme Colors
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);

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

  // Modern Input Decoration
  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon:
        icon != null ? Icon(icon, color: const Color(0xFF1A5276)) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
  );

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
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
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        title: Text(
          'Add Report',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Complainant Information",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A5276),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: _dec('Full Name', icon: Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Full name required';
                        if (v.trim().split(RegExp(r'\s+')).length < 2)
                          return 'Enter first and last name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: _dec(
                        'Email Address',
                        icon: Icons.email_outlined,
                      ).copyWith(fillColor: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      readOnly: _contactReadOnly,
                      decoration: _dec(
                        'Contact Number',
                        icon: Icons.phone_android_outlined,
                      ).copyWith(
                        prefixText: '+63 ',
                        prefixStyle: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                        fillColor:
                            _contactReadOnly
                                ? Colors.white.withOpacity(0.7)
                                : Colors.white,
                      ),
                      validator: (value) {
                        if (_contactReadOnly) return null;
                        if (value == null || value.trim().isEmpty)
                          return 'Required';
                        if (!RegExp(r'^9\d{9}$').hasMatch(value.trim()))
                          return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    const Text(
                      "Incident Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A5276),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: _dec(
                        'Date of Incident',
                        icon: Icons.calendar_today_outlined,
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateController.text =
                                '${pickedDate.month}/${pickedDate.day}/${pickedDate.year}';
                          });
                        }
                      },
                      validator:
                          (v) =>
                              v == null || v.isEmpty ? 'Select a date' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: _dec(
                        'Vehicle Type',
                        icon: Icons.directions_bus_filled_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Jeepney',
                          child: Text('Jeepney'),
                        ),
                        DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                      ],
                      onChanged: (v) => setState(() => _vehicleType = v),
                      validator:
                          (v) => v == null ? 'Select vehicle type' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _plateNumberController,
                      decoration: _dec(
                        'Plate Number',
                        icon: Icons.branding_watermark_outlined,
                      ),
                      validator:
                          (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Enter plate number'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _complaintType,
                      decoration: _dec(
                        'Type of Complaint',
                        icon: Icons.warning_amber_rounded,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Safety',
                          child: Text('Safety'),
                        ),
                        DropdownMenuItem(
                          value: 'Hearing',
                          child: Text('Hearing (Pagdinig)'),
                        ),
                        DropdownMenuItem(
                          value: 'Others',
                          child: Text('Others (Iba pa)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _complaintType = v),
                      validator: (v) => v == null ? 'Select type' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _detailsController,
                      maxLines: 4,
                      decoration: _dec(
                        'Complaint Details',
                      ).copyWith(alignLabelWithHint: true),
                      validator:
                          (v) =>
                              v == null || v.isEmpty ? 'Enter details' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
