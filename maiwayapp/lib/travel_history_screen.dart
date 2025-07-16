import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_report_page.dart';

class TravelHistoryScreen extends StatefulWidget {
  final String userId;

  const TravelHistoryScreen({super.key, required this.userId});

  @override
  State<TravelHistoryScreen> createState() => _TravelHistoryScreenState();
}

class _TravelHistoryScreenState extends State<TravelHistoryScreen> {
  List<Map<String, dynamic>> travelLogs = [];

  @override
  void initState() {
    super.initState();
    print('🔍 Loading travel history for userId: ${widget.userId}');
    _loadTravelHistory();
  }

  Future<void> _loadTravelHistory() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('travel_history')
              .where('userId', isEqualTo: widget.userId)
              .get();

      print('📄 Fetched ${snapshot.docs.length} travel history logs');
      for (var doc in snapshot.docs) {
        print('📝 ${doc.data()}');
      }

      final logs = snapshot.docs.map((doc) => doc.data()).toList();
      setState(() {
        travelLogs = logs.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('🔥 Error loading travel history: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(
    List<Map<String, dynamic>> logs,
  ) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var log in logs) {
      final date = log['date'] ?? 'Unknown';
      grouped.putIfAbsent(date, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedLogs = _groupLogsByDate(travelLogs);

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
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  groupedLogs.isEmpty
                      ? const Center(
                        child: Text(
                          'No travel history yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                      : ListView(
                        children:
                            groupedLogs.entries.map((entry) {
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
                                  ...entry.value.map(
                                    (trip) => GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => TravelDetailScreen(
                                                  trip: trip,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            25,
                                            255,
                                            255,
                                            255,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${trip['origin']} → ${trip['destination']}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white54,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }).toList(),
                      ),
            ),
          ),

          // REPORT BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddReportScreen()),
                );
              },
              icon: const Icon(Icons.report),
              label: const Text("Submit Report"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailItem('Origin', trip['origin']),
            detailItem('Destination', trip['destination']),
            detailItem('Date', trip['date']),
            detailItem('Mode of Transport', trip['modeOfTransport']),
            detailItem('Distance', '${trip['distance']} km'),
            detailItem('Fare', '₱${trip['fare']}'),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddReportScreen()),
                  );
                },
                icon: const Icon(Icons.report),
                label: const Text('Report Travel'),
              ),
            ),
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
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
