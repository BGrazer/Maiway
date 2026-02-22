import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserReportHistoryPage extends StatefulWidget {
  const UserReportHistoryPage({super.key});

  @override
  State<UserReportHistoryPage> createState() => _UserReportHistoryPageState();
}

class _UserReportHistoryPageState extends State<UserReportHistoryPage> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
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

  String _formatDate(dynamic rawDate) {
    try {
      if (rawDate is Timestamp) {
        return DateFormat('MMMM d, y').format(rawDate.toDate());
      } else if (rawDate is String) {
        return rawDate;
      } else {
        return 'Unknown';
      }
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Report History'),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('reports')
                .where('userId', isEqualTo: currentUser!.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reports submitted yet.'));
          }

          final reports = snapshot.data!.docs;

          return ListView.separated(
            itemCount: reports.length,
            padding: const EdgeInsets.all(10),
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final report = reports[index].data() as Map<String, dynamic>;
              final status = report['status'] ?? 'Pending';
              final rawDate = report['date'];

              return ListTile(
                leading: const Icon(Icons.report),
                title: Text(report['typeOfComplaint'] ?? 'Report'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle: ${report['vehicleType']} • Plate: ${report['plateNumber']}",
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
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: Text(report['typeOfComplaint'] ?? 'Report'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Vehicle Type: ${report['vehicleType']}"),
                              Text("Plate Number: ${report['plateNumber']}"),
                              Text("Date Reported: ${_formatDate(rawDate)}"),
                              const SizedBox(height: 10),
                              const Text(
                                "Details:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(report['details'] ?? 'No details'),
                            ],
                          ),
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
            },
          );
        },
      ),
    );
  }
}
