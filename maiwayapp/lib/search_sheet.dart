import 'package:flutter/material.dart';

class SearchSheet extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destinationController;

  const SearchSheet({
    super.key,
    required this.originController,
    required this.destinationController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(originController, 'Origin', Icons.my_location),
            const SizedBox(height: 12),
            _buildTextField(
              destinationController,
              'Destination',
              Icons.location_on,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Start Navigation"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }
}
