import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';
import 'supplier_completed_screen.dart';
import 'supplier_item_price.dart';

class SupplierOrdersScreen extends StatefulWidget {
  final Map<String, dynamic> supplierProfile;
  final String initialFilter;

  const SupplierOrdersScreen({
    super.key,
    required this.supplierProfile,
    this.initialFilter = "All",
  });

  @override
  State<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends State<SupplierOrdersScreen> {
  String searchQuery = "";
  late String activeFilter;
  String? expandedOrderId;
  bool isDrawerOpen = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    activeFilter = widget.initialFilter;
  }

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.supplierProfile['email'];
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.supplierProfile['email']).snapshots(),
      builder: (context, userSnapshot) {
        // Update local map with latest cloud data if available
        Map<String, dynamic> currentProfile = widget.supplierProfile;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          currentProfile = userSnapshot.data!.data() as Map<String, dynamic>;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFE8F1F5),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopSearchBar(),
                    const SizedBox(height: 20),
                    _buildSummaryRow(currentProfile),
                    const SizedBox(height: 20),
                    _buildFilterChips(),
                    const SizedBox(height: 10),
                    Expanded(child: _buildOrdersList(currentProfile)),
                  ],
                ),
              ),
              if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
            ],
          ),
        );
      }
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
                  hintText: "Search Items",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none, color: Colors.black87),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(Map<String, dynamic> currentProfile) {
    String filterEmail = currentProfile['email'] ??"";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('supplierEmail', isEqualTo: filterEmail)
          .snapshots(),
      builder: (context, snapshot) {
        int requests = 0;
        int completed = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'Delivered' || data['status'] == 'Completed') {
              completed++;
            } else {
              requests++;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildSummaryBox("Requests", requests.toString()),
              const SizedBox(width: 15),
              _buildSummaryBox("Completed", completed.toString()),
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

  Widget _buildOrdersList(Map<String, dynamic> currentProfile) {
    String filterName = currentProfile['email'] ??"";
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('supplierEmail', isEqualTo: filterName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var orders = snapshot.data!.docs;

        var filtered = orders.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? 'Purchased';
          String stockName = (data['stockName'] ?? "").toString().toLowerCase();

          if (searchQuery.isNotEmpty && !stockName.contains(searchQuery)) return false;

          if (activeFilter == "Active Order") {
            return status != "Completed" && status != "Delivered";
          } else if (activeFilter == "Completed") {
            return status == "Completed" || status == "Delivered";
          }
          return true;
        }).toList();

        // 💡 Manual Sort by timestamp to avoid missing index crash
        filtered.sort((a, b) {
          var ta = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          var tb = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (filtered.isEmpty) {
          return const Center(child: Text("No orders found matching this filter.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(filtered[index], currentProfile);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc, Map<String, dynamic> currentProfile) {
    var data = doc.data() as Map<String, dynamic>;
    String rawId = doc.id;
    String formalId = "GRH-ORD-${rawId.substring(0, 5).toUpperCase()}";
    bool isExpanded = expandedOrderId == rawId;
    String status = data['status'] ?? "Purchased";
    String dateStr = data['timestamp'] != null 
        ? DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate()) 
        : "-";

    String photoBase64 = currentProfile['photoBase64'] ?? "";

    // Dynamic Color Logic for the top card status
    Color statusColor = status == "Delivered" ? const Color(0xFF66BB6A) : Colors.redAccent;

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
                      ? const Center(
                          child: Icon(Icons.business, size: 40, color: Color(0xFFA65E32)),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['stockCategory'] ?? "Category", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(data['stockName'] ?? "Item", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          Text("Id : $formalId", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                expandedOrderId = isExpanded ? null : rawId;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                              child: Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showAdminPhone(),
                            child: const Icon(Icons.phone_outlined, size: 20),
                          ),
                        ],
                      ),
                      Text("${data['quantity']} box", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  Widget _buildActionBtn(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(5)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }

  void _showAdminPhone() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Manager Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 50, color: Color(0xFFA65E32)),
            const SizedBox(height: 20),
            const Text("01133031316", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
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
          if (currentStatus != "Delivered") ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showUpdateStatusDialog(doc),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Update Stock Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
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

  void _showUpdateStatusDialog(DocumentSnapshot doc) {
    List<String> steps = ["Purchased", "Checked", "Packaging", "On Delivery", "Delivered"];
    var data = doc.data() as Map<String, dynamic>;
    String currentStatus = data['status'] ?? "Purchased";
    int currentIdx = steps.indexOf(currentStatus);
    
    if (currentIdx >= steps.length - 1) return; // Already at last step

    String nextStatus = steps[currentIdx + 1];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Advance Order Status", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to move this order from '$currentStatus' to '$nextStatus'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA65E32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              if (nextStatus == "Delivered") {
                _showImagePickOptions(doc);
              } else {
                await doc.reference.update({'status': nextStatus});
                _showSuccessPopup(nextStatus);
              }
            },
            child: const Text("Confirm Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessPopup(String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            const Text("Status Updated!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Order is now in '$newStatus' phase."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickOptions(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Provide Delivery Proof Picture", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(doc, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(doc, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(DocumentSnapshot doc, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        String base64Image = base64Encode(bytes);

        var data = doc.data() as Map<String, dynamic>;
        String stockId = data['stockId'] ?? "";
        int quantity = data['quantity'] ?? 0;

        // 💡 Fix for Web: Perform queries OUTSIDE the transaction block
        var requestsSnapshot = await FirebaseFirestore.instance
            .collection('stock_requests')
            .where('stockId', isEqualTo: stockId)
            .where('status', isEqualTo: 'Purchased')
            .get();

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // 1. READ PHASE (Must come first)
          DocumentReference inventoryRef = FirebaseFirestore.instance.collection('inventory').doc(stockId);
          DocumentSnapshot inventoryDoc = await transaction.get(inventoryRef);

          // 2. WRITE PHASE (Must come after all gets)
          
          // Update Payment Status to Delivered
          transaction.update(doc.reference, {
            'status': 'Delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
            'deliveryPhotoBase64': base64Image,
          });

          // Update Inventory Quantities
          if (inventoryDoc.exists) {
            var invData = inventoryDoc.data() as Map<String, dynamic>;
            int currentAvail = invData['availableQty'] ?? 0;
            int totalQty = invData['totalQty'] ?? 100;
            int newAvail = currentAvail + quantity;
            int newPercentage = ((newAvail / totalQty) * 100).round();
            
            transaction.update(inventoryRef, {
              'availableQty': newAvail, 
              'percentage': newPercentage
            });
          }

          // Update stock_requests status to Completed
          for (var r in requestsSnapshot.docs) {
            transaction.update(r.reference, {'status': 'Completed'});
          }
        });

        if (mounted) {
          _showSuccessPopup("Delivered");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing delivery: $e"), backgroundColor: Colors.red),
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
              _buildDrawerItem(Icons.home, "Home", onTap: () => Navigator.pop(context)),
              _buildDrawerItem(
                Icons.shopping_cart_outlined,
                "Orders",
                isActive: activeFilter == "Active Order",
                onTap: () {
                  setState(() {
                    isDrawerOpen = false;
                    activeFilter = "Active Order";
                  });
                },
              ),
              _buildDrawerItem(
                Icons.sell_outlined,
                "Item Price",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierItemPrice(
                        supplierProfile: widget.supplierProfile,
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.assignment_turned_in_outlined,
                "Completed",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierCompletedScreen(
                        supplierProfile: widget.supplierProfile,
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.settings_outlined,
                "Settings",
                onTap: () async {
                  setState(() => isDrawerOpen = false);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(userProfile: widget.supplierProfile),
                    ),
                  );
                },
              ),
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
      decoration: BoxDecoration(
        color: isActive ? Colors.black.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
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
