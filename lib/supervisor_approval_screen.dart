import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'profile_settings_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'supervisor_room_assignment.dart';
import 'inventory_store_scan_page.dart';
import 'team_screen.dart';
import 'login_screen.dart';

class SupervisorApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> supervisorProfile;
  const SupervisorApprovalScreen({super.key, required this.supervisorProfile});

  @override
  State<SupervisorApprovalScreen> createState() => _SupervisorApprovalScreenState();
}

class _SupervisorApprovalScreenState extends State<SupervisorApprovalScreen> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  File? _profileImage;
  Map<String, bool> expandedTiles = {};

  // Real-time stats
  int stockPurchasedMonth = 0;
  int stockPending = 0;
  int stockCompletedMonth = 0;
  int lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
    _fetchStats();
  }

  Future<void> _loadSavedProfileImage() async {
    final String uniqueId = widget.supervisorProfile['username'] ?? widget.supervisorProfile['email'] ?? 'default_user';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString('manager_profile_path_$uniqueId');

    if (imagePath != null && imagePath.isNotEmpty) {
      File savedFile = File(imagePath);
      if (await savedFile.exists()) {
        setState(() {
          _profileImage = savedFile;
        });
      }
    }
  }

  void _fetchStats() {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    FirebaseFirestore.instance
        .collection('payments')
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => stockPurchasedMonth = snapshot.docs.length);
    });

    FirebaseFirestore.instance
        .collection('stock_requests')
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => stockPending = snapshot.docs.length);
    });

    FirebaseFirestore.instance
        .collection('stock_requests')
        .where('status', isEqualTo: 'Completed')
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => stockCompletedMonth = snapshot.docs.length);
    });

    FirebaseFirestore.instance
        .collection('inventory')
        .where('percentage', isLessThanOrEqualTo: 20)
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => lowStockCount = snapshot.docs.length);
    });
  }

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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                // Sticky Search Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: const Color(0xFFF1F5F9),
                  child: _buildSearchField(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (searchQuery.isEmpty) ...[
                          _buildReloadButton(),
                          const SizedBox(height: 10),
                          _buildStatsGrid(),
                          const SizedBox(height: 25),
                        ],
                        _buildHistoryHeader(),
                        _buildApprovalHistoryList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: _buildDownloadButton(),
                ),
              ],
            ),
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _generatePDFReport,
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        label: const Text("Download Stock Approvals",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF302B2C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 5,
        ),
      ),
    );
  }

  Future<void> _generatePDFReport() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMMM yyyy, hh:mm a').format(now);

    // Fetch data for the report
    final snapshot = await FirebaseFirestore.instance
        .collection('stock_requests')
        .orderBy('timestamp', descending: true)
        .get();

    final requests = snapshot.docs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Stock Approvals Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Grand Renai", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text("Generated on: $formattedDate"),
            pw.Text("Generated by: ${widget.supervisorProfile['username'] ?? 'Supervisor'}"),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Stock Name', 'Supervisor', 'Qty', 'Status', 'Approved By'],
              data: requests.map((doc) {
                final data = doc.data();
                final ts = data['timestamp'] as Timestamp?;
                final date = ts != null ? DateFormat('dd/MM/yy').format(ts.toDate()) : 'N/A';
                final status = data['status'] ?? 'Pending';
                final qty = status == 'Purchased' ? data['orderedQty'] : data['requestedQty'];
                
                return [
                  date,
                  data['stockName'] ?? 'Unknown',
                  data['supervisorName'] ?? 'N/A',
                  "$qty box",
                  status,
                  data['approvedBy'] ?? 'Pending',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );

    try {
      final bytes = await pdf.save();
      
      if (kIsWeb) {
        // On Web, Printing.sharePdf triggers a browser download/print
        await Printing.sharePdf(bytes: bytes, filename: 'Stock_Approvals_Report.pdf');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF Report generated"), backgroundColor: Colors.green),
        );
      } else {
        // On Mobile, try to save to local storage AND share
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final file = File("${directory.path}/Stock_Approvals_Report_${DateTime.now().millisecondsSinceEpoch}.pdf");
          await file.writeAsBytes(bytes);
          
          await Printing.sharePdf(bytes: bytes, filename: 'Stock_Approvals_Report.pdf');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PDF Report saved to ${file.path}"), backgroundColor: Colors.green),
          );
        } else {
          // Fallback if directory is not accessible
          await Printing.sharePdf(bytes: bytes, filename: 'Stock_Approvals_Report.pdf');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.supervisorProfile['email']).snapshots(),
      builder: (context, snapshot) {
        String photoBase64 = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          photoBase64 = (snapshot.data!.data() as Map<String, dynamic>)['photoBase64'] ?? "";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.list, size: 30),
                onPressed: () => setState(() => isDrawerOpen = true),
              ),
              const Text("Approvals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.supervisorProfile)),
                  );
                  _loadSavedProfileImage();
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: photoBase64.isNotEmpty
                          ? MemoryImage(base64Decode(photoBase64))
                          : (_profileImage != null ? FileImage(_profileImage!) : null),
                      child: (photoBase64.isEmpty && _profileImage == null) ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                    ),
                    const Text("Supervisor", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
        decoration: const InputDecoration(
          hintText: "Search Stock Name",
          prefixIcon: Icon(Icons.search, color: Color(0xFFC98A6B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildReloadButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          _fetchStats();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Refreshing data..."), backgroundColor: Color(0xFFC98A6B)),
          );
        },
        icon: const Icon(Icons.refresh, color: Color(0xFFC98A6B), size: 18),
        label: const Text("Reload Data", style: TextStyle(color: Color(0xFFC98A6B), fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: [
        _buildStatCard("Stock Purchased (Month)", stockPurchasedMonth.toString()),
        _buildStatCard("Total Stock Pending", stockPending.toString()),
        _buildStatCard("Stock Completed (Month)", stockCompletedMonth.toString()),
        _buildStatCard("Low Stock Item", lowStockCount.toString()),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC98A6B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF302B2C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: const BoxDecoration(
        color: Color(0xFFD2B49C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: const Text("Approvals History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildApprovalHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stock_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var requests = snapshot.data!.docs.where((doc) {
          String name = (doc['stockName'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        if (requests.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: const Center(child: Text("No request history found.", style: TextStyle(color: Colors.grey))),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildApprovalTile(requests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildApprovalTile(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String status = data['status'] ?? "Pending";
    int requestedQty = data['requestedQty'] ?? 0;
    int orderedQty = data['orderedQty'] ?? 0;
    bool isPurchased = status == "Purchased";
    bool isCompleted = status == "Completed";
    String stockId = data['stockId'] ?? "";
    bool isExpanded = expandedTiles[doc.id] ?? false;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('inventory').doc(stockId).snapshots(),
      builder: (context, invSnapshot) {
        String photoBase64 = "";
        if (invSnapshot.hasData && invSnapshot.data!.exists) {
          photoBase64 = (invSnapshot.data!.data() as Map<String, dynamic>)['photoBase64'] ?? "";
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      image: photoBase64.isNotEmpty 
                        ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                        : null,
                    ),
                    child: photoBase64.isEmpty ? const Icon(Icons.inventory_2_outlined, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['stockName'] ?? "Unknown Stock", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Request by ${data['supervisorName'] ?? 'Supervisor'}", 
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2B49C).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (isPurchased || isCompleted) ? "Ordered $orderedQty box" : "Requested $requestedQty box",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.black87),
                    onPressed: () => setState(() => expandedTiles[doc.id] = !isExpanded),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE6D7).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: (isPurchased || isCompleted) ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Stock Item", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isPurchased || isCompleted) ...[
                            Text("Approved by ${data['approvedBy'] ?? 'Manager'}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (data['timestamp'] != null)
                              Text(DateFormat('dd MMMM yyyy').format((data['timestamp'] as Timestamp).toDate()), 
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ] else
                            const Text("Not Checked", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.blueAccent : (isPurchased ? Colors.green : Colors.redAccent),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isCompleted ? "Delivered" : (isPurchased ? "Ordered" : "Pending"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _buildDrawerOverlay(double screenWidth) {
    return Stack(
      children: [
        GestureDetector(onTap: () => setState(() => isDrawerOpen = false), child: Container(color: Colors.black.withOpacity(0.3))),
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
              _buildDrawerItem(Icons.fact_check_outlined, "Approval", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.assignment_ind_outlined,
                "Room Assignment",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorRoomAssignment(supervisorProfile: widget.supervisorProfile),
                    ),
                  );
                },
              ),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupervisorStockTracking(supervisorProfile: widget.supervisorProfile),
                  ),
                );
              }),
              _buildDrawerItem(Icons.people_outline, "Team", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.settings_outlined, "Settings", onTap: () async {
                setState(() => isDrawerOpen = false);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.supervisorProfile)));
                _loadSavedProfileImage();
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
      decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.white, width: 0),
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
        icon: const Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
        label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
