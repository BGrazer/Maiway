import 'package:flutter/material.dart';

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

  List<Map<String, String>> users = [
    {"name": "Trisha Norton", "status": "Pending"},
    {"name": "Jolene Orr", "status": "Submitted"},
    {"name": "Aryan Roy", "status": "Under Review"},
    {"name": "Elvin Bond", "status": "Pending"},
    {"name": "Hazafa Anas", "status": "Submitted"},
    {"name": "Nisha Kumari", "status": "Under Review"},
    {"name": "Sophia", "status": "Submitted"},
    {"name": "Rhazita Pratapa", "status": "Pending"},
  ];

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

  @override
  Widget build(BuildContext context) {
    final filteredUsers =
        users.where((user) {
          final matchesSearch = user['name']!.toLowerCase().contains(
            searchQueryReports.toLowerCase(),
          );
          final matchesFilter =
              statusFilterReports == null ||
              user['status'] == statusFilterReports;
          return matchesSearch && matchesFilter;
        }).toList();

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
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search user by name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list),
                      onSelected: (value) {
                        setState(() {
                          statusFilterReports = value == 'All' ? null : value;
                        });
                      },
                      itemBuilder:
                          (context) => const [
                            PopupMenuItem(value: 'All', child: Text('All')),
                            PopupMenuItem(
                              value: 'Pending',
                              child: Text('Pending'),
                            ),
                            PopupMenuItem(
                              value: 'Under Review',
                              child: Text('Under Review'),
                            ),
                            PopupMenuItem(
                              value: 'Submitted',
                              child: Text('Submitted'),
                            ),
                          ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQueryReports = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final status = user['status'];
                    Color statusColor;
                    Color bgColor;

                    switch (status) {
                      case 'Submitted':
                        statusColor = Colors.green;
                        bgColor = Colors.green.withOpacity(0.2);
                        break;
                      case 'Under Review':
                        statusColor = Colors.orange;
                        bgColor = Colors.orange.withOpacity(0.2);
                        break;
                      case 'Pending':
                      default:
                        statusColor = Colors.blue;
                        bgColor = Colors.blue.withOpacity(0.2);
                        break;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6699CC),
                        child: Text(
                          _getInitials(user['name']!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user['name']!),
                      subtitle: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status!,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showUserDetails(context, user),
                    );
                  },
                ),
              ),
            ],
          ),

          // Surveys Tab
          Column(
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
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  void _showUserDetails(BuildContext context, Map<String, String> user) {
    String selectedStatus = user['status']!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            title: Text(user['name']!),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Date Received: June 7, 2025"),
                const SizedBox(height: 10),
                const Text("File Report: Not available"),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Change Status:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 5),
                Column(
                  children:
                      ['Pending', 'Under Review', 'Submitted'].map((
                        statusOption,
                      ) {
                        return RadioListTile<String>(
                          title: Text(statusOption),
                          value: statusOption,
                          groupValue: selectedStatus,
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value!;
                              user['status'] = value;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Export Report (PDF)"),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Export feature is not yet connected to the database.",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actionsAlignment: MainAxisAlignment.center,
          ),
        );
      },
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
                Text("Details:"),
                Text(survey['details']),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Export Survey Anomaly (PDF)"),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Export feature is not yet connected to the database.",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actionsAlignment: MainAxisAlignment.center,
          ),
        );
      },
    );
  }
}
