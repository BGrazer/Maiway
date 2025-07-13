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

  List<Map<String, dynamic>> surveyAnomalies = [
    {
      "id": "S001",
      "participant": "Alice Johnson",
      "anomalyScore": 0.92,
      "details": "High deviation in answers for question 4 and 7",
      "date": "June 5, 2025",
    },
    {
      "id": "S002",
      "participant": "Bob Smith",
      "anomalyScore": 0.88,
      "details": "Inconsistent response pattern detected",
      "date": "June 6, 2025",
    },
    {
      "id": "S003",
      "participant": "Charlie Lee",
      "anomalyScore": 0.95,
      "details": "Unusual response timing and pattern",
      "date": "June 6, 2025",
    },
  ];

  String searchQueryReports = '';
  String? statusFilterReports;
  String searchQuerySurveys = '';
  String searchQuery = '';
  String selectedStatus = 'All';
  String selectedVehicle = 'All';

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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSurveys =
        surveyAnomalies.where((survey) {
          return survey['participant'].toLowerCase().contains(
            searchQuerySurveys.toLowerCase(),
          );
        }).toList();

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
        children: [_buildReportsTab(), _buildSurveyTab(filteredSurveys)],
      ),
    );
  }

  Widget _buildSurveyTab(List<Map<String, dynamic>> filteredSurveys) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search survey participant',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuerySurveys = value;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: filteredSurveys.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final survey = filteredSurveys[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6699CC),
                  child: Text(
                    _getInitials(survey['participant']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(survey['participant']),
                subtitle: Text(
                  "Anomaly Score: ${survey['anomalyScore'].toStringAsFixed(2)}",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSurveyDetails(context, survey),
              );
            },
          ),
        ),
      ],
    );
  }

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
                    searchQuery = value.toLowerCase();
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
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Submitted',
                          child: Text('Submitted'),
                        ),
                        DropdownMenuItem(
                          value: 'Under Review',
                          child: Text('Under Review'),
                        ),
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
                        DropdownMenuItem(
                          value: 'Jeepney',
                          child: Text('Jeepney'),
                        ),
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
            stream:
                FirebaseFirestore.instance.collection('reports').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No reports found.'));
              }
              final filteredReports =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final fullName = data['fullName']?.toLowerCase() ?? '';
                    final email = data['email']?.toLowerCase() ?? '';
                    final status = data['status'] ?? 'Pending';
                    final vehicle = data['vehicleType'] ?? '';
                    final matchesSearch =
                        fullName.contains(searchQuery) ||
                        email.contains(searchQuery);
                    final matchesStatus =
                        selectedStatus == 'All' || status == selectedStatus;
                    final matchesVehicle =
                        selectedVehicle == 'All' || vehicle == selectedVehicle;
                    return matchesSearch && matchesStatus && matchesVehicle;
                  }).toList();

              if (filteredReports.isEmpty) {
                return const Center(
                  child: Text('No reports matched the filters.'),
                );
              }

              return ListView.separated(
                itemCount: filteredReports.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final reportDoc = filteredReports[index];
                  final report = reportDoc.data() as Map<String, dynamic>;
                  final status = report['status'] ?? 'Pending';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        report['fullName']?.substring(0, 1).toUpperCase() ??
                            '?',
                      ),
                    ),
                    title: Text(report['fullName'] ?? 'No Name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle: ${report['vehicleType']} | Plate: ${report['plateNumber']}',
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => _showReportDetails(context, reportDoc.id, report),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSurveyDetails(BuildContext context, Map<String, dynamic> survey) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            title: Text("Survey ID: ${survey['id']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Participant: ${survey['participant']}"),
                const SizedBox(height: 10),
                Text("Date: ${survey['date']}"),
                const SizedBox(height: 10),
                Text(
                  "Anomaly Score: ${survey['anomalyScore'].toStringAsFixed(2)}",
                ),
                const SizedBox(height: 10),
                const Text("Details:"),
                Text(survey['details']),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> report,
  ) {
    String currentStatus = report['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(report['typeOfComplaint'] ?? 'Report'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${report['fullName']}'),
                  Text('Email: ${report['email']}'),
                  Text('Phone: ${report['contactNumber']}'),
                  Text('Vehicle Type: ${report['vehicleType']}'),
                  Text('Plate Number: ${report['plateNumber']}'),
                  Text('Date: ${report['date'] ?? 'Not specified'}'),
                  const SizedBox(height: 10),
                  const Text('Details:'),
                  Text(report['details'] ?? 'No details'),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: currentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Update Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'Under Review',
                        child: Text('Under Review'),
                      ),
                      DropdownMenuItem(
                        value: 'Submitted',
                        child: Text('Submitted'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && value != currentStatus) {
                        FirebaseFirestore.instance
                            .collection('reports')
                            .doc(docId)
                            .update({'status': value});
                        setState(() {
                          currentStatus = value;
                        });
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
    );
  }
}
