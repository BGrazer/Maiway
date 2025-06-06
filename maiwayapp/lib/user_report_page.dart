import 'package:flutter/material.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _vehicleController.dispose();
    _plateNumberController.dispose();
    _locationController.dispose();
    _complaintController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Implement report submission logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      Navigator.pop(context);
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.blue),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6699CC),
        elevation: 5,
        title: const Text('Add Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _dateController,
                decoration: _buildInputDecoration('Date'),
                validator:
                    (value) => value!.isEmpty ? 'Please enter the date' : null,
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
                          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _vehicleController,
                decoration: _buildInputDecoration('Vehicle'),
                validator:
                    (value) =>
                        value!.isEmpty ? 'Please enter the vehicle' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _plateNumberController,
                decoration: _buildInputDecoration('Plate Number'),
                validator:
                    (value) =>
                        value!.isEmpty ? 'Please enter the plate number' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _locationController,
                decoration: _buildInputDecoration('Location'),
                validator:
                    (value) =>
                        value!.isEmpty ? 'Please enter the location' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _complaintController,
                maxLines: 3,
                decoration: _buildInputDecoration('Complaint'),
                validator:
                    (value) =>
                        value!.isEmpty ? 'Please enter the complaint' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _imageController,
                decoration: _buildInputDecoration('Image URL or Path'),
                validator:
                    (value) =>
                        value!.isEmpty ? 'Please provide an image' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF457B9D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Submit',
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
