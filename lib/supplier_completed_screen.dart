import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';
import 'supplier_orders_screen.dart';
import 'supplier_item_price.dart';

class SupplierCompletedScreen extends StatefulWidget {
  final Map<String, dynamic> supplierProfile;
  const SupplierCompletedScreen({super.key, required this.supplierProfile});

  @override
  State<SupplierCompletedScreen> createState() => _SupplierCompletedScreenState();
}

class _SupplierCompletedScreenState extends State<SupplierCompletedScreen> {
  bool isDrawerOpen = false;

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String? email = widget.supplierProfile['email']?.toString().toLowerCase();
    if (email != null && email.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
                Expanded(child: _buildCompletedList()),
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
        label: const Text("Download Completed Orders",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC98A6B),
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
        .collection('payments')
        .where('supplierEmail', isEqualTo: widget.supplierProfile['email'])
        .where('status', whereIn: ['Completed', 'Delivered'])
        .get();

    final orders = snapshot.docs;
    
    // Sort manually by timestamp descending
    orders.sort((a, b) {
      var ta = (a.data())['timestamp'] as Timestamp?;
      var tb = (b.data())['timestamp'] as Timestamp?;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

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
                  pw.Text("Completed Orders Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Grand Renai", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text("Generated on: $formattedDate"),
            pw.Text("Supplier: ${widget.supplierProfile['name'] ?? 'Supplier'}"),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Order ID', 'Item Name', 'Qty', 'Amount (RM)', 'Processed By'],
              data: orders.map((doc) {
                final data = doc.data();
                final ts = data['timestamp'] as Timestamp?;
                final date = ts != null ? DateFormat('dd/MM/yy').format(ts.toDate()) : 'N/A';
                final orderId = doc.id.substring(0, 8).toUpperCase();
                final amount = (data['totalAmount'] ?? 0.0).toDouble();
                
                return [
                  date,
                  orderId,
                  data['stockName'] ?? 'N/A',
                  "${data['quantity']} box",
                  NumberFormat('#,##0.00').format(amount),
                  data['processedBy'] ?? 'N/A',
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
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );

    try {
      final bytes = await pdf.save();
      final fileName = "Completed_Orders_Report_${DateTime.now().millisecondsSinceEpoch}.pdf";

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF Report generated"), backgroundColor: Colors.green),
        );
      } else {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final file = File("${directory.path}/$fileName");
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PDF Report saved to ${file.path}"), backgroundColor: Colors.green),
          );
        } else {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: const BoxDecoration(
        color: Color(0xFFC98A6B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white, size: 30),
            onPressed: () => setState(() => isDrawerOpen = true),
          ),
          const SizedBox(width: 10),
          const Text(
            "Completed Orders",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('supplierEmail', isEqualTo: widget.supplierProfile['email'])
          .where('status', whereIn: ['Completed', 'Delivered'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // Manual Sort by timestamp descending
        docs.sort((a, b) {
          var ta = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          var tb = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (docs.isEmpty) {
          return const Center(child: Text("No completed orders found.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildCompletedCard(docs[index]),
        );
      },
    );
  }

  Widget _buildCompletedCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String orderId = doc.id;
    
    // Dates
    Timestamp? purchaseTs = data['timestamp'] as Timestamp?;
    Timestamp? deliveredTs = data['deliveredAt'] as Timestamp?; // Assuming this field exists or will be added on delivery
    
    String purchasedDate = purchaseTs != null ? DateFormat('dd MMM yyyy').format(purchaseTs.toDate()) : "-";
    String deliveredDate = deliveredTs != null ? DateFormat('dd MMM yyyy').format(deliveredTs.toDate()) : "Recently";
    
    double amount = (data['totalAmount'] ?? 0.0).toDouble();
    String provePhoto = data['deliveryPhotoBase64'] ?? ""; // Assuming picture is stored here

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Order Status", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Text("COMPLETED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const Divider(height: 25),
          Text(
            "RM ${amount.toStringAsFixed(2)}",
            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          _buildDetailRow(Icons.person_outline, "Processed by", data['processedBy'] ?? "N/A"),
          _buildDetailRow(Icons.inventory_2_outlined, "Item Name", data['stockName'] ?? "N/A"),
          _buildDetailRow(Icons.qr_code_scanner_outlined, "Order ID", orderId.substring(0, 8).toUpperCase()),
          _buildDetailRow(Icons.calendar_today_outlined, "Purchased Date", purchasedDate),
          _buildDetailRow(Icons.local_shipping_outlined, "Delivered Date", deliveredDate),
          
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Quantity: ${data['quantity']} box", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
              if (provePhoto.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _showProvePicture(provePhoto),
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text("Prove Picture", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC98A6B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                const Text("No Photo Prove", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text("$label : ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
        ],
      ),
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
              _buildDrawerItem(
                Icons.shopping_cart_outlined,
                "Orders",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierOrdersScreen(supplierProfile: widget.supplierProfile, initialFilter: "Active Order"),
                    ),
                  );
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
              _buildDrawerItem(Icons.assignment_turned_in_outlined, "Completed", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
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
