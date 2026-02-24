import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);
  final Color surfaceWhite = Colors.white;

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
      'December',
    ];
    return months[month];
  }

  // --- HEADER & NAVIGATION ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        title: const Text(
          'ADMIN PANEL',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: surfaceWhite,
        foregroundColor: primaryBlue,
        elevation: 4,
        shadowColor: primaryBlue.withValues(alpha: 0.2),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          indicatorColor: primaryBlue,
          indicatorWeight: 4,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          tabs: const [Tab(text: "REPORTS"), Tab(text: "SURVEYS")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReportsTab(), _buildSurveysTab()],
      ),
    );
  }

  // --- FILTER & SEARCH UI ---

  Widget _buildSearchHeader({required bool isSurvey}) {
    bool isFiltered =
        selectedVehicle != 'All' || (!isSurvey && selectedStatus != 'All');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged:
                    (v) => setState(() {
                      if (isSurvey) {
                        searchQuerySurveys = v.toLowerCase();
                      } else {
                        searchQueryReports = v.toLowerCase();
                      }
                    }),
                decoration: InputDecoration(
                  hintText:
                      isSurvey ? 'Search routes...' : 'Search name/email...',
                  prefixIcon: Icon(Icons.search, color: primaryBlue),
                  filled: true,
                  fillColor: surfaceWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  onSelected: (value) {
                    setState(() {
                      if (value == 'Reset') {
                        selectedVehicle = 'All';
                        selectedStatus = 'All';
                      } else if (['Jeepney', 'Bus', 'All'].contains(value)) {
                        selectedVehicle = value;
                      } else {
                        selectedStatus = value;
                      }
                    });
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'Reset',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Reset All Filters',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const PopupMenuDivider(),
                        _buildPopupItem(
                          'Jeepney',
                          'Jeepney Only',
                          selectedVehicle,
                        ),
                        _buildPopupItem('Bus', 'Bus Only', selectedVehicle),
                        if (!isSurvey) ...[
                          const PopupMenuDivider(),
                          _buildPopupItem(
                            'Pending',
                            'Show Pending',
                            selectedStatus,
                          ),
                          _buildPopupItem(
                            'Under Review',
                            'Show Under Review',
                            selectedStatus,
                          ),
                          _buildPopupItem(
                            'Submitted',
                            'Show Submitted',
                            selectedStatus,
                          ),
                        ],
                      ],
                ),
              ),
              if (isFiltered)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: Colors.orange,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    String label,
    String currentValue,
  ) {
    bool isSelected = value == currentValue;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryBlue : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_circle, color: primaryBlue, size: 18),
          ],
        ],
      ),
    );
  }

  // --- REPORTS SECTION ---

  Widget _buildReportsTab() {
    return Column(
      children: [
        _buildSearchHeader(isSurvey: false),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('reports').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                );
              }
              final filtered =
                  snapshot.data!.docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['fullName']?.toLowerCase() ?? '';
                    final status = d['status'] ?? 'Pending';
                    final vehicle = d['vehicleType'] ?? '';
                    return name.contains(searchQueryReports) &&
                        (selectedStatus == 'All' || status == selectedStatus) &&
                        (selectedVehicle == 'All' ||
                            vehicle == selectedVehicle);
                  }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final report = doc.data() as Map<String, dynamic>;
                  final name = report['fullName'] ?? 'Anonymous';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: skyBlueBackground.withValues(alpha: 0.4),
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      subtitle: Text(
                        report['typeOfComplaint'] ?? 'General Report',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: _statusBadge(report['status'] ?? 'Pending'),
                      onTap:
                          () => _showEnhancedSheet(
                            context,
                            "Report Details",
                            doc.id,
                            report,
                            isSurvey: false,
                          ),
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

  // --- SURVEYS SECTION ---

  Widget _buildSurveysTab() {
    return Column(
      children: [
        _buildSearchHeader(isSurvey: true),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('surveys').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                );
              }

              final grouped =
                  <String, Map<String, List<Map<String, dynamic>>>>{};

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final route = data['route'] ?? 'Unknown';
                final vehicle = data['vehicleType'] ?? 'Unknown';
                final date =
                    (data['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now();

                if (selectedVehicle != 'All' && vehicle != selectedVehicle) {
                  continue;
                }
                if (!route.toString().toLowerCase().contains(
                  searchQuerySurveys,
                )) {
                  continue;
                }

                final monthYear = "${_monthName(date.month)} ${date.year}";
                grouped.putIfAbsent(route, () => {});
                grouped[route]!.putIfAbsent(monthYear, () => []);
                grouped[route]![monthYear]!.add(data);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: grouped.keys.length,
                itemBuilder: (context, index) {
                  final route = grouped.keys.elementAt(index);
                  final routeData = grouped[route]!;

                  // Calculate total anomalies for the route level
                  int routeAnomalies = 0;
                  for (var monthData in routeData.values) {
                    routeAnomalies +=
                        monthData.where((s) => s['anomalous'] == true).length;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      iconColor: primaryBlue,
                      leading: Icon(
                        Icons.alt_route_rounded,
                        color: primaryBlue,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              route,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                          if (routeAnomalies > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "⚠️ $routeAnomalies",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      children:
                          routeData.entries.map((entry) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "${entry.value.length} Total Responses",
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.analytics_outlined,
                                size: 20,
                              ),
                              onTap:
                                  () => _showEnhancedSheet(
                                    context,
                                    "Survey Group: $route",
                                    "",
                                    {},
                                    entries: entry.value,
                                    isSurvey: true,
                                  ),
                            );
                          }).toList(),
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

  // --- COMMON UI HELPERS ---

  Widget _statusBadge(String status) {
    Color color =
        status == 'Submitted'
            ? Colors.green
            : status == 'Under Review'
            ? Colors.orange
            : primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showEnhancedSheet(
    BuildContext context,
    String title,
    String docId,
    Map<String, dynamic> data, {
    List<Map<String, dynamic>>? entries,
    required bool isSurvey,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child:
                      isSurvey
                          ? _buildSurveyDetailList(entries!)
                          : _buildReportDetailContent(docId, data),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildReportDetailContent(String docId, Map<String, dynamic> report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailBlock("USER INFORMATION", [
            _rowInfo(Icons.person_outline, "Full Name", report['fullName']),
            _rowInfo(Icons.email, "Email", report['email']),
            _rowInfo(
              Icons.phone_iphone_rounded,
              "Contact",
              report['contactNumber'],
            ),
          ]),
          const SizedBox(height: 24),
          _detailBlock("INCIDENT DATA", [
            _rowInfo(Icons.commute_rounded, "Vehicle", report['vehicleType']),
            _rowInfo(Icons.pin_rounded, "Plate", report['plateNumber']),
            _rowInfo(Icons.calendar_month_rounded, "Date", report['date']),
          ]),
          const SizedBox(height: 24),
          const Text(
            "DESCRIPTION",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black38,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              report['details'] ?? 'No additional details.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            value: report['status'] ?? 'Pending',
            decoration: InputDecoration(
              labelText: 'Action: Update Status',
              labelStyle: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: skyBlueBackground.withValues(alpha: 0.05),
            ),
            items:
                ['Pending', 'Under Review', 'Submitted']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                FirebaseFirestore.instance
                    .collection('reports')
                    .doc(docId)
                    .update({'status': value});
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSurveyDetailList(List<Map<String, dynamic>> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        bool isAnom = e['anomalous'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isAnom ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAnom ? Colors.red.shade100 : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isAnom ? Colors.red.shade900 : primaryBlue,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            title: Text(
              e['name'] ?? 'Anonymous',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Paid: ₱${e['fare_given']} | Target: ₱${e['original_fare']}",
            ),
            trailing: isAnom
                ? Icon(Icons.warning_rounded, color: Colors.red.shade900)
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  Widget _detailBlock(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _rowInfo(IconData icon, String label, String? val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          Expanded(
            child: Text(
              val ?? 'N/A',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
