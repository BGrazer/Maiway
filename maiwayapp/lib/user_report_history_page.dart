import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: UserReportHistoryPage(),
  ));
}

class UserReportHistoryPage extends StatelessWidget {
  final List<Map<String, String>> userReports = [
    {
      "reportType": "Overpricing",
      "vehicleType": "Jeepney",
      "plateNumber": "NAB 1234",
      "status": "Submitted",
      "date": "June 9, 2025",
      "details": "Driver charged more than posted fare."
    },
    {
      "reportType": "Misconduct",
      "vehicleType": "Bus",
      "plateNumber": "XYZ 5678",
      "status": "Under Review",
      "date": "June 8, 2025",
      "details": "Driver was rude and refused to give change."
    },
    {
      "reportType": "Reckless Driving",
      "vehicleType": "Tricycle",
      "plateNumber": "ABC 1111",
      "status": "Pending",
      "date": "June 7, 2025",
      "details": "Vehicle was swerving through traffic dangerously."
    },
  ];

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
        title: const Text('My Report History'),
        backgroundColor: const Color(0xFF6699CC),
      ),
      body: ListView.separated(
        itemCount: userReports.length,
        padding: const EdgeInsets.all(10),
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final report = userReports[index];
          final statusColor = _getStatusColor(report['status']!);
          final bgColor = _getStatusBackgroundColor(report['status']!);

          return ListTile(
            leading: const Icon(Icons.report, color: Colors.black54),
            title: Text("${report['reportType']}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Vehicle: ${report['vehicleType']} • Plate: ${report['plateNumber']}"),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report['status']!,
                    style: TextStyle(
                      color: statusColor,
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
                builder: (BuildContext context) {
                  return Center(
                    child: AlertDialog(
                      title: Text(report['reportType']!),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Vehicle Type: ${report['vehicleType']}"),
                          Text("Plate Number: ${report['plateNumber']}"),
                          Text("Date Reported: ${report['date']}"),
                          const SizedBox(height: 10),
                          const Text("Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(report['details']!),
                        ],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        TextButton(
                          child: const Text("Close"),
                          onPressed: () => Navigator.of(context).pop(),
                        )
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
