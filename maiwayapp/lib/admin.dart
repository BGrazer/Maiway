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

  Color _getStatusColor(String statusTag) {
    if (statusTag.contains("🟥")) return Colors.red;
    if (statusTag.contains("🟠")) return Colors.orange;
    if (statusTag.contains("🟢")) return Colors.green;
    return Colors.grey;
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

  // --------------------- SURVEYS ---------------------
  Widget _buildSurveysTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search route (e.g., R. Papa to Tayuman)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuerySurveys = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('surveys')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No surveys found.'));
              }

              final grouped = <String, List<Map<String, dynamic>>>{};

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final route = (data['route'] ?? 'Unknown') as String;
                grouped.putIfAbsent(route, () => []).add(data);
              }

              // Convert map to list and sort alphabetically by route
              final sortedRoutes = grouped.keys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              // Apply search filter
              final filteredRoutes = sortedRoutes.where((route) {
                return route.toLowerCase().contains(searchQuerySurveys);
              }).toList();

              return ListView.builder(
                itemCount: filteredRoutes.length,
                itemBuilder: (context, index) {
                  final route = filteredRoutes[index];
                  final routeData = grouped[route]!;

                  final total = routeData.length;
                  final overcharged = routeData.where((d) => d['anomalous'] == true).length;
                  final avgFare = routeData
                      .map((d) => (d['fare_given'] ?? 0).toDouble())
                      .fold(0.0, (a, b) => a + b) / total;
                  final avgDistance = routeData
                      .map((d) => double.tryParse(d['distance'].toString()) ?? 0.0)
                      .fold(0.0, (a, b) => a + b) / total;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: overcharged > 0 ? Colors.red : Colors.green,
                      child: Text(route.split(' ').first[0].toUpperCase()),
                    ),
                    title: Text("🚏 Route: $route"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🧑 Participants: $total"),
                        Text("⚠️ Overcharged: $overcharged"),
                        Text("💰 Avg Fare: ₱${avgFare.toStringAsFixed(2)}"),
                        Text("📏 Avg Distance: ${avgDistance.toStringAsFixed(2)} km"),
                      ],
                    ),
                    onTap: () => _showRouteDetails(context, route, routeData),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRouteDetails(BuildContext context, String route, List<Map<String, dynamic>> entries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("Surveys for $route", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          child: Text(
                            (e['name'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                        trailing: Icon(
                          e['anomalous'] == true ? Icons.warning : Icons.check_circle,
                          color: e['anomalous'] == true ? Colors.red : Colors.green,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------- REPORTS ---------------------
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
                final fullName = data['fullName']?.toLowerCase() ?? '';
                final email = data['email']?.toLowerCase() ?? '';
                final status = data['status'] ?? 'Pending';
                final vehicle = data['vehicleType'] ?? '';
                final matchesSearch =
                    fullName.contains(searchQueryReports) || email.contains(searchQueryReports);
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
                  final status = report['status'] ?? 'Pending';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        report['fullName']?.substring(0, 1).toUpperCase() ?? '?',
                      ),
                    ),
                    title: Text(report['fullName'] ?? 'No Name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehicle: ${report['vehicleType']} | Plate: ${report['plateNumber']}'),
                        const SizedBox(height: 4),
                        Container(
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
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}