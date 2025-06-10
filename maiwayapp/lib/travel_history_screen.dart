import 'package:flutter/material.dart';
import 'user_report_page.dart'; 

class TravelHistoryScreen extends StatelessWidget {
  const TravelHistoryScreen({super.key});

  final List<Map<String, dynamic>> travelLogs = const [
    {
      'date': 'Today',
      'route': 'Intramuros to Binondo',
      'modes': ['Jeep', 'Tricycle'],
      'startTime': '3:30 PM',
      'endTime': '4:00 PM',
    },
    {
      'date': '7 Days',
      'route': 'Pandacan to SM Manila',
      'modes': ['Jeep', 'Bus'],
      'startTime': '10:00 AM',
      'endTime': '10:45 AM',
    },
    {
      'date': '7 Days',
      'route': 'Intramuros to Binondo',
      'modes': ['LRT', 'Tricycle'],
      'startTime': '1:20 PM',
      'endTime': '2:00 PM',
    },
    {
      'date': '30 Days',
      'route': 'Binondo to Pandacan',
      'modes': ['Bus', 'Jeep'],
      'startTime': '11:10 AM',
      'endTime': '12:00 PM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedLogs = {};

    for (var log in travelLogs) {
      groupedLogs.putIfAbsent(log['date'], () => []).add(log);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF40729A),
      appBar: AppBar(
        title: const Text(
          'Travel History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF40729A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: groupedLogs.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...entry.value.map((trip) => GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelDetailScreen(trip: trip),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(25, 255, 255, 255),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                trip['route'],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class TravelDetailScreen extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TravelDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF40729A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF40729A),
        title: const Text(
          'Travel Details',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailItem('Route', trip['route']),
            detailItem('Start Time', trip['startTime']),
            detailItem('End Time', trip['endTime']),
            detailItem('Modes Used', trip['modes'].join(', ')),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddReportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.report),
                label: const Text('Report Travel'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget detailItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$title: ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            TextSpan(
              text: content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
