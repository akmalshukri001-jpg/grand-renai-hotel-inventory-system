import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class HousekeepingPerformanceScreen extends StatefulWidget {
  final Map<String, dynamic> staffProfile;
  const HousekeepingPerformanceScreen({super.key, required this.staffProfile});

  @override
  State<HousekeepingPerformanceScreen> createState() => _HousekeepingPerformanceScreenState();
}

class _HousekeepingPerformanceScreenState extends State<HousekeepingPerformanceScreen> {
  int totalTasksMonth = 0;
  int totalAllStaffTasksMonth = 0;
  int totalDamagedMonth = 0;
  double totalHoursMonth = 0.0;
  bool isStarred = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculatePerformance();
  }

  Future<void> _calculatePerformance() async {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    String email = widget.staffProfile['email'];
    String staffId = widget.staffProfile['staffId'];

    try {
      // 1. Fetch Rooms Completed by THIS staff this month
      var roomsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('rooms')
          .where('completedByEmail', isEqualTo: email)
          .where('status', isEqualTo: 'Completed')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .get();
      
      // 2. Fetch Rooms Completed by ALL staff this month
      var allRoomsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('rooms')
          .where('status', isEqualTo: 'Completed')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      // 3. Fetch Damage Reports this month
      var damagedSnapshot = await FirebaseFirestore.instance
          .collection('damaged_reports')
          .where('staffEmail', isEqualTo: email)
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      // 4. Fetch Starred Status
      var perfDoc = await FirebaseFirestore.instance.collection('housekeeping_performance').doc(staffId).get();
      bool savedStar = false;
      if (perfDoc.exists) {
        savedStar = perfDoc.data()?['isStarred'] ?? false;
      }

      // 5. Calculate "Active Hours"
      Map<String, List<DateTime>> activitiesByDay = {};

      void addActivity(Timestamp? ts) {
        if (ts == null) return;
        DateTime dt = ts.toDate();
        String dayKey = DateFormat('yyyy-MM-dd').format(dt);
        activitiesByDay.putIfAbsent(dayKey, () => []).add(dt);
      }

      for (var doc in roomsSnapshot.docs) {
        addActivity(doc['timestamp'] as Timestamp?);
      }
      for (var doc in damagedSnapshot.docs) {
        addActivity(doc['timestamp'] as Timestamp?);
      }

      double hoursSum = 0;
      activitiesByDay.forEach((day, times) {
        if (times.length > 1) {
          times.sort();
          Duration diff = times.last.difference(times.first);
          hoursSum += diff.inMinutes / 60.0;
        } else {
          hoursSum += 0.25;
        }
      });

      // 6. Sync/Update to housekeeping_performance collection
      await FirebaseFirestore.instance.collection('housekeeping_performance').doc(staffId).set({
        'staffId': staffId,
        'name': widget.staffProfile['name'],
        'email': email,
        'role': widget.staffProfile['role'],
        'month': DateFormat('MMMM yyyy').format(now),
        'totalTasks': roomsSnapshot.docs.length,
        'totalDamaged': damagedSnapshot.docs.length,
        'activeHours': hoursSum.toStringAsFixed(1),
        'isStarred': savedStar,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          totalTasksMonth = roomsSnapshot.docs.length;
          totalAllStaffTasksMonth = allRoomsSnapshot.docs.length;
          totalDamagedMonth = damagedSnapshot.docs.length;
          totalHoursMonth = hoursSum;
          isStarred = savedStar;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error calculating performance: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleStar() async {
    setState(() => isStarred = !isStarred);
    try {
      // 1. Update performance collection
      await FirebaseFirestore.instance
          .collection('housekeeping_performance')
          .doc(widget.staffProfile['staffId'])
          .update({'isStarred': isStarred});

      // 2. Sync to users collection so Team Screen can see it immediately
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.staffProfile['email'])
          .update({'isStarred': isStarred});
    } catch (e) {
      debugPrint("Error updating star status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String photoBase64 = widget.staffProfile['photoBase64'] ?? "";
    
    double taskPercentage = totalAllStaffTasksMonth > 0 
        ? (totalTasksMonth / totalAllStaffTasksMonth) * 100 
        : 0.0;
    
    // Assuming 160 active hours as 100% capacity for a month
    double hoursPercentage = (totalHoursMonth / 160) * 100;
    if (hoursPercentage > 100) hoursPercentage = 100.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Staff Performance", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isStarred ? Icons.star : Icons.star_border, color: Colors.white, size: 30),
            onPressed: _toggleStar,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildProfileHeader(photoBase64),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Monthly Overview (${DateFormat('MMMM').format(DateTime.now())})"),
                  const SizedBox(height: 15),
                  
                  _buildPerformanceCard(
                    "Tasks Completed", 
                    "$totalTasksMonth / $totalAllStaffTasksMonth", 
                    Icons.task_alt, 
                    Colors.green,
                    percentage: taskPercentage,
                    subLabel: "${taskPercentage.toStringAsFixed(1)}% of total team output",
                  ),
                  
                  _buildPerformanceCard(
                    "Active Hours", 
                    "${totalHoursMonth.toStringAsFixed(1)} hrs", 
                    Icons.timer_outlined, 
                    Colors.blue,
                    percentage: hoursPercentage,
                    subLabel: "${hoursPercentage.toStringAsFixed(1)}% of monthly capacity",
                  ),
                  
                  _buildPerformanceCard(
                    "Damaged Reported", 
                    totalDamagedMonth.toString(), 
                    Icons.report_problem_outlined, 
                    Colors.redAccent
                  ),
                  
                  const SizedBox(height: 30),
                  _buildNoteBox(),
                  const SizedBox(height: 30),
                  _buildAwardButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAwardButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF302B2C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
        ),
        onPressed: _showAwardConfirmation,
        icon: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
        label: const Text("Nominate for Performance Award", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAwardConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Nomination"),
        content: Text("Are you sure you want to award ${widget.staffProfile['name']} as the Monthly Best Staff? This will update all dashboards."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () {
              Navigator.pop(context);
              _updateGlobalAward();
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGlobalAward() async {
    setState(() => isLoading = true);
    try {
      String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
      
      await FirebaseFirestore.instance.collection('awards').doc('monthly_best').set({
        'name': widget.staffProfile['name'],
        'month': currentMonth,
        'photoBase64': widget.staffProfile['photoBase64'] ?? "",
        'staffId': widget.staffProfile['staffId'],
        'awardedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Award updated across all dashboards!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error awarding staff: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildProfileHeader(String photoBase64) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: photoBase64.isNotEmpty
                ? MemoryImage(base64Decode(photoBase64))
                : null,
            child: photoBase64.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.staffProfile['name'] ?? "Unknown", 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (isStarred) const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.stars, color: Colors.amber, size: 20),
                    ),
                  ],
                ),
                Text(widget.staffProfile['staffId'] ?? "No ID", 
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.staffProfile['role'] ?? "Staff", 
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildPerformanceCard(String label, String value, IconData icon, Color color, {double? percentage, String? subLabel}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
          if (percentage != null) ...[
            const SizedBox(height: 15),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(subLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
              ),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildNoteBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Performance data is synced in real-time based on team activity logs. Active hours reset daily.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
