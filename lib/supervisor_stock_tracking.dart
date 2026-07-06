import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'profile_settings_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_room_assignment.dart';
import 'inventory_store_scan_page.dart';
import 'team_screen.dart';
import 'login_screen.dart';

class SupervisorStockTracking extends StatefulWidget {
  final Map<String, dynamic> supervisorProfile;

  const SupervisorStockTracking({
    super.key,
    required this.supervisorProfile,
  });

  @override
  State<SupervisorStockTracking> createState() => _SupervisorStockTrackingState();
}

class _SupervisorStockTrackingState extends State<SupervisorStockTracking> {
  String searchQuery = "";
  String activeFilter = "All";
  String? expandedOrderId;
  bool isDrawerOpen = false;

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
      backgroundColor: const Color(0xFFE8F1F5),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopSearchBar(),
                const SizedBox(height: 20),
                _buildSummaryRow(),
                const SizedBox(height: 20),
                _buildFilterChips(),
                const SizedBox(height: 10),
                Expanded(child: _buildOrdersList()),
              ],
            ),
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => isDrawerOpen = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.list, color: Colors.black87, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEDC9AF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.black54),
                  hintText: "Search Items or Suppliers",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.notifications_none, color: Colors.black87),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('payments').snapshots(),
      builder: (context, snapshot) {
        int purchased = 0;
        int delivered = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'Delivered' || data['status'] == 'Completed') {
              delivered++;
            } else {
              purchased++;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildSummaryBox("Purchased", purchased.toString()),
              const SizedBox(width: 15),
              _buildSummaryBox("Delivered", delivered.toString()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryBox(String label, String count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFA65E32),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Text(count, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    List<String> filters = ["All", "Active Order", "Completed"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((f) {
          bool isSelected = activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (val) => setState(() => activeFilter = f),
              backgroundColor: const Color(0xFFFBE9E7),
              selectedColor: const Color(0xFFE6BEA5),
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.black54, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('payments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var orders = snapshot.data!.docs;
        var filtered = orders.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? 'Purchased';
          String stockName = (data['stockName'] ?? "").toString().toLowerCase();
          String supplierName = (data['supplierName'] ?? "").toString().toLowerCase();

          if (searchQuery.isNotEmpty && !stockName.contains(searchQuery) && !supplierName.contains(searchQuery)) return false;

          if (activeFilter == "Active Order") {
            return status != "Completed" && status != "Delivered";
          } else if (activeFilter == "Completed") {
            return status == "Completed" || status == "Delivered";
          }
          return true;
        }).toList();

        filtered.sort((a, b) {
          var ta = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          var tb = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (filtered.isEmpty) return const Center(child: Text("No tracking data found."));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String rawId = doc.id;
    String formalId = "GRH-ORD-${rawId.substring(0, 5).toUpperCase()}";
    bool isExpanded = expandedOrderId == rawId;
    String status = data['status'] ?? "Purchased";
    String dateStr = data['timestamp'] != null 
        ? DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate()) 
        : "-";

    Color statusColor = status == "Delivered" || status == "Completed" ? const Color(0xFF66BB6A) : Colors.redAccent;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('companyName', isEqualTo: data['supplierName']).limit(1).snapshots(),
      builder: (context, userSnapshot) {
        String photoBase64 = "";
        if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
          var supplierData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          photoBase64 = supplierData['photoBase64'] ?? "";
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEDC9AF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        image: photoBase64.isNotEmpty 
                            ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: photoBase64.isEmpty 
                          ? const Center(child: Icon(Icons.business, size: 40, color: Color(0xFFA65E32)))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['supplierName'] ?? "Enterprise", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(data['stockName'] ?? "Item", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Row(
                            children: [
                              Text("Id : $formalId", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => expandedOrderId = isExpanded ? null : rawId),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                  child: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                                ),
                              ),
                              // Call icon removed for supervisor
                            ],
                          ),
                          Text("${data['quantity']} box", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10)),
                            child: Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              if (isExpanded) _buildExpansionDetails(doc, data, dateStr),
            ],
          ),
        );
      }
    );
  }

  Widget _buildExpansionDetails(DocumentSnapshot doc, Map<String, dynamic> data, String date) {
    String currentStatus = data['status'] ?? "Purchased";
    List<String> steps = ["Purchased", "Checked", "Packaging", "On Delivery", "Delivered"];
    int currentIdx = steps.indexOf(currentStatus);
    if (currentIdx == -1) currentIdx = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStepRow(
              steps[i], 
              i <= currentIdx ? date : "-", 
              isDone: i <= currentIdx,
              showReceipt: steps[i] == "Purchased",
              onReceiptTap: () => _showReceiptDialog(data, doc.id),
              showUpload: steps[i] == "Delivered",
              provePhoto: steps[i] == "Delivered" ? data['deliveryPhotoBase64'] : null,
            ),
            if (i < steps.length - 1) _buildStepLine(),
          ],
        ],
      ),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("GRAND RENAI", style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300, fontSize: 18)),
              const Text("PURCHASE RECEIPT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              _buildReceiptDetailRow("Order ID", "GRH-ORD-${docId.substring(0, 5).toUpperCase()}"),
              _buildReceiptDetailRow("Item Name", data['stockName'] ?? "N/A"),
              _buildReceiptDetailRow("Quantity", "${data['quantity']} Units"),
              _buildReceiptDetailRow("Supplier", data['supplierName'] ?? "N/A"),
              _buildReceiptDetailRow("Processed By", data['processedBy'] ?? "Manager"),
              _buildReceiptDetailRow("Purchased Date", data['timestamp'] != null ? DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate()) : "-"),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Paid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("RM ${(data['totalAmount'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent)),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Close", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStepRow(String label, String date, {bool showReceipt = false, VoidCallback? onReceiptTap, bool showUpload = false, bool isDone = false, String? provePhoto}) {
    return Row(
      children: [
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF66BB6A) : const Color(0xFFD1D9E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 20),
        Text(date, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        if (showReceipt) 
          GestureDetector(
            onTap: onReceiptTap,
            child: _buildMiniBtn("Receipt"),
          ),
        if (showUpload && provePhoto != null) 
          GestureDetector(
            onTap: () => _showProvePicture(provePhoto),
            child: _buildMiniBtn("View Picture"),
          )
        else if (showUpload)
          _buildMiniBtn("No Picture"),
      ],
    );
  }

  void _showProvePicture(String base64Img) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFFC98A6B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Delivery Prove", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(base64Decode(base64Img), fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(
      margin: const EdgeInsets.only(left: 50),
      height: 20,
      width: 2,
      child: CustomPaint(painter: DashLinePainter()),
    );
  }

  Widget _buildMiniBtn(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
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
              _buildDrawerItem(Icons.home, "Home", onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
              _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorInventoryScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.supervisorProfile)));
              }),
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
              _buildDrawerItem(Icons.track_changes, "Stock Tracking", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(Icons.people, "Team", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.settings, "Settings", onTap: () async {
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

class DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 3, dashSpace = 3, startY = 0;
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
