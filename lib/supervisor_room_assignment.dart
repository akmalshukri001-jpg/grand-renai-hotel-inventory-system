import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'profile_settings_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'inventory_store_scan_page.dart';
import 'team_screen.dart';
import 'login_screen.dart';

class SupervisorRoomAssignment extends StatefulWidget {
  final Map<String, dynamic> supervisorProfile;
  const SupervisorRoomAssignment({super.key, required this.supervisorProfile});

  @override
  State<SupervisorRoomAssignment> createState() => _SupervisorRoomAssignmentState();
}

class _SupervisorRoomAssignmentState extends State<SupervisorRoomAssignment> {
  String searchQuery = "";
  int selectedLevel = 10; // Default level
  String? selectedStaffEmail;
  String? selectedStaffName;
  String statusFilter = "All"; // All, Pending, Completed
  bool isDrawerOpen = false;
  bool _isPrinting = false;

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.supervisorProfile['email'];
    if (email.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Room Assignments", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.list, size: 30),
          onPressed: () => setState(() => isDrawerOpen = true),
        ),
        actions: [
          IconButton(
            icon: _isPrinting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC98A6B)))
              : const Icon(Icons.print_outlined),
            tooltip: "Print Level QR Codes",
            onPressed: _isPrinting ? null : _generateBulkRoomQR,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStaffSelector(),
              _buildLevelFilter(),
              _buildStatusFilter(),
              Expanded(child: _buildRoomsList()),
            ],
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  Widget _buildStaffSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Housekeeping').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var staffList = snapshot.data!.docs;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("1. Select Housekeeping Staff", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    var staff = staffList[index].data() as Map<String, dynamic>;
                    bool isSelected = selectedStaffEmail == staff['email'];
                    String photoBase64 = staff['photoBase64'] ?? "";

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedStaffEmail = staff['email'];
                          selectedStaffName = staff['name'];
                        });
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 15),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: isSelected ? const Color(0xFFC98A6B) : Colors.grey.shade200,
                              child: CircleAvatar(
                                radius: 27,
                                backgroundImage: photoBase64.isNotEmpty ? MemoryImage(base64Decode(photoBase64)) : null,
                                child: photoBase64.isEmpty ? const Icon(Icons.person) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              staff['name'] ?? "Staff",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFFC98A6B) : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLevelFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: List.generate(10, (index) {
            int level = 10 - index;
            bool isSelected = selectedLevel == level;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text("Level $level"),
                selected: isSelected,
                onSelected: (val) => setState(() => selectedLevel = level),
                selectedColor: const Color(0xFFC98A6B),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: ["All", "Pending", "Completed"].map((status) {
          bool isSelected = statusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (val) => setState(() => statusFilter = status),
              selectedColor: const Color(0xFFC98A6B),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoomsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('housekeeping_tasks')
          .doc('level_$selectedLevel')
          .collection('rooms')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var rooms = snapshot.data!.docs;
        List<int> roomNumbers = List.generate(10, (i) => (selectedLevel * 100) + (i + 1));
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: roomNumbers.length,
          itemBuilder: (context, index) {
            int roomNum = roomNumbers[index];
            var matches = rooms.where((d) => d.id == "room_$roomNum");
            var roomDoc = matches.isNotEmpty ? matches.first : null;

            Map<String, dynamic>? roomData;
            if (roomDoc != null) {
              roomData = roomDoc.data() as Map<String, dynamic>;
            }

            String status = roomData?['status'] ?? "Unassigned";
            String currentAssignment = roomData?['assignedToName'] ?? "No Staff";
            bool isCompleted = status == 'Completed';

            // Apply Status Filter
            if (statusFilter == "Pending" && (isCompleted || status == "Unassigned")) return const SizedBox.shrink();
            if (statusFilter == "Completed" && !isCompleted) return const SizedBox.shrink();

            Color statusColor = isCompleted ? Colors.green : (status == "Pending" ? Colors.orange : Colors.grey);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.3) : (status == "Pending" ? Colors.orange.withOpacity(0.3) : Colors.transparent)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.meeting_room, color: statusColor),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Room $roomNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(isCompleted ? "Cleaned by $currentAssignment" : "Assigned to: $currentAssignment", 
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isCompleted)
                    ElevatedButton(
                      onPressed: selectedStaffEmail == null ? null : () => _assignRoom(roomNum),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC98A6B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                      child: Text(status == "Pending" ? "Reassign" : "Assign", style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateBulkRoomQR() async {
    setState(() => _isPrinting = true);
    try {
      final pdf = pw.Document();
      
      // Generate 10 rooms for the selected level
      List<int> roomNumbers = List.generate(10, (i) => (selectedLevel * 100) + (i + 1));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Grand Renai - Level $selectedLevel Room QR Codes", 
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: roomNumbers.map((roomNum) {
                  final String roomCode = "ROOM_${selectedLevel}_$roomNum";
                  
                  return pw.Container(
                    width: 150,
                    height: 160,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("GRAND RENAI", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text("ROOM $roomNum", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: roomCode,
                          width: 80,
                          height: 80,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text("Level $selectedLevel", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Room_QR_Level_$selectedLevel.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _assignRoom(int roomNumber) async {
    try {
      await FirebaseFirestore.instance
          .collection('housekeeping_tasks')
          .doc("level_$selectedLevel")
          .collection('rooms')
          .doc("room_$roomNumber")
          .set({
        'roomNumber': roomNumber,
        'level': selectedLevel,
        'status': 'Pending',
        'assignedToEmail': selectedStaffEmail,
        'assignedToName': selectedStaffName,
        'assignedBy': widget.supervisorProfile['name'],
        'assignmentTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Room $roomNumber assigned to $selectedStaffName"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDrawerOverlay(double screenWidth) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => isDrawerOpen = false),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: screenWidth * 0.55,
          height: double.infinity,
          color: const Color(0xFFC98A6B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              _buildDrawerItem(Icons.home_outlined, "Home", onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
              _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorInventoryScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.assignment_ind_outlined, "Room Assignment", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.settings_remote,
                "Inventory Store Station",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryStoreScanPage(supervisorProfile: widget.supervisorProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorStockTracking(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.people_outline, "Team", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.settings_outlined, "Settings", onTap: () async {
                setState(() => isDrawerOpen = false);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.supervisorProfile)));
              }),
              const Spacer(),
              _buildLogoutButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, {bool isActive = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () async {
          await _updateUserStatus(false);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout, color: Colors.black),
        label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
