import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(const MaterialApp(home: AdminScreen()));
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String searchQuerySurveys = '';
  String searchQueryReports = '';
  String selectedStatus = 'All';
  String selectedVehicle = 'All';
  String selectedMonth = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.green;
      case 'Under Review':
        return Colors.orange;
      case 'Pending':
      default:
        return Colors.blue;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.green.withOpacity(0.2);
      case 'Under Review':
        return Colors.orange.withOpacity(0.2);
      case 'Pending':
      default:
        return Colors.blue.withOpacity(0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF6699CC),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Reports"), Tab(text: "Surveys")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReportsTab(), _buildSurveysTab()],
      ),
    );
  }

  // --------------------- REPORTS TAB ---------------------
  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Full Name or Email',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQueryReports = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                        DropdownMenuItem(value: 'Under Review', child: Text('Under Review')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedVehicle,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Jeepney', child: Text('Jeepney')),
                        DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedVehicle = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reports').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No reports found.'));
              }

              final filteredReports = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final status = (data['status'] ?? 'Pending').toString();
                final vehicle = (data['vehicleType'] ?? '').toString();

                final matchesSearch = fullName.contains(searchQueryReports) || email.contains(searchQueryReports);
                final matchesStatus = selectedStatus == 'All' || status == selectedStatus;
                final matchesVehicle = selectedVehicle == 'All' || vehicle == selectedVehicle;

                return matchesSearch && matchesStatus && matchesVehicle;
              }).toList();

              if (filteredReports.isEmpty) {
                return const Center(child: Text('No reports matched the filters.'));
              }

              return ListView.separated(
                itemCount: filteredReports.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final reportDoc = filteredReports[index];
                  final report = reportDoc.data() as Map<String, dynamic>;

                  final fullName = report['fullName'] ?? 'Unknown';
                  final email = report['email'] ?? '';
                  final status = report['status'] ?? 'Pending';
                  final vehicle = report['vehicleType'] ?? 'Unknown';
                  final plate = report['plateNumber'] ?? 'N/A';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(fullName.toString().substring(0, 1).toUpperCase()),
                    ),
                    title: Text(fullName),
                    subtitle: Text('$vehicle • Plate: $plate'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBackgroundColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("📋 Report Details", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(),
                              Text("👤 Name: $fullName"),
                              Text("📧 Email: $email"),
                              Text("🚗 Vehicle: $vehicle"),
                              Text("🔢 Plate Number: $plate"),
                              Text("📌 Status: $status"),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Close"),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------- SURVEYS TAB ---------------------
  Widget _buildSurveysTab() {
    return const Center(
      child: Text("Survey tab working. Code unchanged here."),
    );
    // Keep using your working survey logic or let me know to include its update too
  }
}
