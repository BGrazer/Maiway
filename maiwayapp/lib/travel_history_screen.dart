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
  // Theme Colors
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> travelLogs = [];
  String _searchQuery = "";
  String? _selectedMonth;
  String? _selectedYear;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final List<String> _years = ['2023', '2024', '2025', '2026'];

  @override
  void initState() {
    super.initState();
    _loadTravelHistory();
  }

  Future<void> _loadTravelHistory() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('travel_history')
              .where('userId', isEqualTo: widget.userId)
              .get();

      final logs = snapshot.docs.map((doc) => doc.data()).toList();
      setState(() {
        travelLogs = logs.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading travel history: $e');
    }
  }

  // --- FILTER DIALOG ---
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Text(
                    "Filter Trips",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogDropdown(
                        "Select Month",
                        _months,
                        _selectedMonth,
                        (val) => setDialogState(() => _selectedMonth = val),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogDropdown(
                        "Select Year",
                        _years,
                        _selectedYear,
                        (val) => setDialogState(() => _selectedYear = val),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMonth = null;
                          _selectedYear = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Apply",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDialogDropdown(
    String hint,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items:
              items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- LOGIC: Grouping, Searching, and Filtering ---
  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(
    List<Map<String, dynamic>> logs,
  ) {
    final filtered =
        logs.where((log) {
          final origin = (log['origin'] ?? "").toString().toLowerCase();
          final dest = (log['destination'] ?? "").toString().toLowerCase();
          final dateStr = (log['date'] ?? "").toString();

          bool matchesSearch =
              origin.contains(_searchQuery.toLowerCase()) ||
              dest.contains(_searchQuery.toLowerCase());
          bool matchesMonth =
              _selectedMonth == null || dateStr.contains(_selectedMonth!);
          bool matchesYear =
              _selectedYear == null || dateStr.contains(_selectedYear!);

          return matchesSearch && matchesMonth && matchesYear;
        }).toList();

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var log in filtered) {
      final date = log['date'] ?? 'Unknown';
      grouped.putIfAbsent(date, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedLogs = _groupLogsByDate(travelLogs);

    return Scaffold(
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        title: Text(
          'Travel History',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // SEARCH & FILTER HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      prefixIcon: Icon(Icons.search, color: primaryBlue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showFilterDialog,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ACTIVE FILTER CHIP
          if (_selectedMonth != null || _selectedYear != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActionChip(
                backgroundColor: Colors.white,
                avatar: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.redAccent,
                ),
                label: Text(
                  "Clear ${_selectedMonth ?? ''} ${_selectedYear ?? ''}",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed:
                    () => setState(() {
                      _selectedMonth = null;
                      _selectedYear = null;
                    }),
              ),
            ),

          Expanded(
            child:
                groupedLogs.isEmpty
                    ? Center(
                      child: Text(
                        "No trips found",
                        style: TextStyle(
                          color: primaryBlue.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children:
                          groupedLogs.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(
                                  (trip) => _buildTripCard(trip),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
          ),

          // REPORT BUTTON FOOTER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddReportScreen()),
                  ),
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: const Text("Submit New Report"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TravelDetailScreen(trip: trip)),
            ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: skyBlueBackground.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_bus_filled_rounded, color: primaryBlue),
        ),
        title: Text(
          "${trip['origin']} to ${trip['destination']}",
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          trip['modeOfTransport'] ?? 'Public Transport',
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.black26,
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
    final Color primaryBlue = const Color(0xFF1A5276);
    final Color skyBlueBackground = const Color(0xFF91C9F1);

    return Scaffold(
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Trip Details',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _detailRow(
                    Icons.location_on_outlined,
                    'Origin',
                    trip['origin'],
                    primaryBlue,
                  ),
                  _divider(),
                  _detailRow(
                    Icons.flag_outlined,
                    'Destination',
                    trip['destination'],
                    primaryBlue,
                  ),
                  _divider(),
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Date',
                    trip['date'],
                    primaryBlue,
                  ),
                  _divider(),
                  _detailRow(
                    Icons.directions_subway_outlined,
                    'Transport',
                    trip['modeOfTransport'],
                    primaryBlue,
                  ),
                  _divider(),
                  _detailRow(
                    Icons.straighten_rounded,
                    'Distance',
                    '${trip['distance']} km',
                    primaryBlue,
                  ),
                  _divider(),
                  _detailRow(
                    Icons.payments_outlined,
                    'Total Fare',
                    '₱${trip['fare']}',
                    primaryBlue,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddReportScreen()),
                );
              },
              icon: const Icon(Icons.report_problem_rounded),
              label: const Text(
                'Report an Issue',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 24);

  Widget _detailRow(
    IconData icon,
    String title,
    String content,
    Color primary, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primary),
        const SizedBox(width: 12),
        Text(
          '$title:',
          style: const TextStyle(color: Colors.black45, fontSize: 14),
        ),
        const Spacer(),
        Text(
          content,
          style: TextStyle(
            color: isBold ? Colors.green.shade700 : primary,
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
