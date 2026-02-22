// ✅ Merged Admin Panel with Reports and Surveys working together

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
  int? selectedMonth;
  int? selectedYear;

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

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
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

 Widget _buildSurveysTab() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search route...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (value) => setState(() => searchQuerySurveys = value.toLowerCase()),
        ),
        const SizedBox(height: 10),
        
        // Filters Row
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: IntrinsicWidth(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Type Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedVehicle,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Type',
                            border: OutlineInputBorder(),
                            // Adjust size or add padding
                            contentPadding: EdgeInsets.symmetric(vertical: 15), // Adjust padding
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(value: 'Jeepney', child: Text('Jeepney')),
                            DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                          ],
                          onChanged: (value) => setState(() => selectedVehicle = value!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Month Filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 15), // Adjust padding
                          ),
                          items: List.generate(12, (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(_monthName(index + 1)),
                          ))..insert(0, const DropdownMenuItem( value: null, child: Text('All'))),
                          onChanged: (value) => setState(() => selectedMonth = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Year Filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 15), // Adjust padding
                          ),
                          items: List.generate(5, (index) => DropdownMenuItem(
                            value: DateTime.now().year - index,
                            child: Text((DateTime.now().year - index).toString()),
                          ))..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                          onChanged: (value) => setState(() => selectedYear = value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // Surveys List
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildSurveyList(),
        ),
      ],
    ),
  );
}
  Widget _buildSurveyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surveys').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No surveys found.'));
        }

        final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final route = (data['route'] ?? 'Unknown') as String;
          final vehicle = data['vehicleType'] ?? 'Unknown';
          final timestamp = data['timestamp'];
          final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();

          if (selectedVehicle != 'All' && vehicle != selectedVehicle) continue;
          if ((selectedMonth != null && date.month != selectedMonth) ||
              (selectedYear != null && date.year != selectedYear)) {
            continue;
          }

          final monthYear = "${_monthName(date.month)} ${date.year}";
          grouped.putIfAbsent(route, () => {});
          grouped[route]!.putIfAbsent(monthYear, () => []);
          grouped[route]![monthYear]!.add(data);
        }

        final filteredRoutes = grouped.keys.where((r) => r.toLowerCase().contains(searchQuerySurveys)).toList()..sort();

        return ListView.builder(
          itemCount: filteredRoutes.length,
          itemBuilder: (context, index) {
            final route = filteredRoutes[index];
            return ExpansionTile(
              title: Text("🚏 Route: $route"),
              children: grouped[route]!.entries.map((entry) {
                final monthYear = entry.key;
                final entries = entry.value;
                final total = entries.length;
                final overcharged = entries.where((d) => d['anomalous'] == true).length;
                final avgFare = entries.map((e) => (e['fare_given'] ?? 0).toDouble()).fold(0.0, (a, b) => a + b) / total;
                final avgDistance = entries.map((e) => double.tryParse('${e['distance']}') ?? 0.0).fold(0.0, (a, b) => a + b) / total;

                return ListTile(
                  title: Text("📅 $monthYear"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🧑 Participants: $total"),
                      Text("⚠️ Overcharged: $overcharged"),
                      Text("💰 Avg Fare: ₱${avgFare.toStringAsFixed(2)}"),
                      Text("📏 Avg Distance: ${avgDistance.toStringAsFixed(2)} km"),
                    ],
                  ),
                  onTap: () => _showSurveyDetails(context, "$route ($monthYear)", entries),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _showSurveyDetails(BuildContext context, String title, List<Map<String, dynamic>> entries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Surveys: $title", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: e['anomalous'] == true ? Colors.red : Colors.green,
                        child: Text((e['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(e['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Fare Given: ₱${e['fare_given']}"),
                          Text("Predicted Fare: ₱${e['original_fare']}"),
                          Text("Vehicle: ${e['vehicleType'] ?? 'N/A'}"),
                        ],
                      ),
                      trailing: Icon(e['anomalous'] == true ? Icons.warning : Icons.check_circle, color: e['anomalous'] == true ? Colors.red : Colors.green),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
                onChanged: (value) => setState(() => searchQueryReports = value.toLowerCase()),
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
                      onChanged: (value) => setState(() => selectedStatus = value!),
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
                      onChanged: (value) => setState(() => selectedVehicle = value!),
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
                final fullName = data['fullName']?.toLowerCase() ?? '';
                final email = data['email']?.toLowerCase() ?? '';
                final status = data['status'] ?? 'Pending';
                final vehicle = data['vehicleType'] ?? '';
                return (fullName.contains(searchQueryReports) || email.contains(searchQueryReports)) &&
                    (selectedStatus == 'All' || selectedStatus == status) &&
                    (selectedVehicle == 'All' || selectedVehicle == vehicle);
              }).toList();

              return ListView.separated(
                itemCount: filteredReports.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = filteredReports[index];
                  final report = doc.data() as Map<String, dynamic>;
                  final status = report['status'] ?? 'Pending';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text((report['fullName'] ?? '?')[0].toUpperCase()),
                    ),
                    title: Text(report['fullName'] ?? 'No Name'),
                    subtitle: Text('Vehicle: ${report['vehicleType']} | Plate: ${report['plateNumber']}'),
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
                    onTap: () => _showReportDetails(doc.id, report),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  void _showReportDetails(String docId, Map<String, dynamic> report) {
    String currentStatus = report['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: currentStatus,
                decoration: const InputDecoration(labelText: 'Update Status'),
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Under Review', child: Text('Under Review')),
                  DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                ],
                onChanged: (value) {
                  if (value != null && value != currentStatus) {
                    FirebaseFirestore.instance.collection('reports').doc(docId).update({'status': value});
                    Navigator.of(context).pop();
                  }
                },
              )
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
