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
  final TextEditingController _searchController = TextEditingController();

  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);

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
    currentUser = FirebaseAuth.instance.currentUser;
  }

  // --- UI HELPER METHODS ---

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.green.shade600;
      case 'Under Review':
        return Colors.orange.shade700;
      default:
        return const Color(0xFF1A5276);
    }
  }

  String _formatDate(dynamic rawDate) {
    try {
      if (rawDate is Timestamp)
        return DateFormat('MMM d, yyyy').format(rawDate.toDate());
      if (rawDate is String) return rawDate;
      return 'Unknown';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Allows dropdowns to update inside the dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                "Filter Reports",
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
                    (val) {
                      setDialogState(() => _selectedMonth = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDialogDropdown("Select Year", _years, _selectedYear, (
                    val,
                  ) {
                    setDialogState(() => _selectedYear = val);
                  }),
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
                    setState(() {}); // Refresh main UI
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
            );
          },
        );
      },
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

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        title: Text(
          'Report History',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900),
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
          // SEARCH & FILTER ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search complaints...",
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

          // ACTIVE FILTER INDICATOR (CLEAR BUTTON)
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
                  "Filters: ${_selectedMonth ?? ''} ${_selectedYear ?? ''} (Clear)",
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
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('reports')
                      .where('userId', isEqualTo: currentUser?.uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  );
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return _emptyState("No reports yet");

                final filteredDocs =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final complaint =
                          (data['typeOfComplaint'] ?? "")
                              .toString()
                              .toLowerCase();
                      final dateStr = _formatDate(data['date']);
                      return complaint.contains(_searchQuery.toLowerCase()) &&
                          (_selectedMonth == null ||
                              dateStr.contains(_selectedMonth!)) &&
                          (_selectedYear == null ||
                              dateStr.contains(_selectedYear!));
                    }).toList();

                if (filteredDocs.isEmpty)
                  return _emptyState("No matching reports");

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (context, index) {
                    final report =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTS ---

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: InkWell(
                  onTap: () => _showDetails(report),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                report['typeOfComplaint'] ?? 'Report',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatDate(report['date']).split(',')[0],
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryBlue.withOpacity(0.5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${report['vehicleType']} • ${report['plateNumber']}",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Report Detail",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 20),
                _detailRow("Vehicle", report['vehicleType']),
                _detailRow("Plate", report['plateNumber']),
                _detailRow("Date", _formatDate(report['date'])),
                const Divider(height: 30),
                const Text(
                  "DETAILS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      report['details'] ?? 'No details',
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Done",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _detailRow(String label, String? val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.black45)),
          Text(
            val ?? 'N/A',
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(
          color: primaryBlue.withOpacity(0.4),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
