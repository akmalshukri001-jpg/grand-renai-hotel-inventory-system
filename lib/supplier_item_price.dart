import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'profile_settings_screen.dart';
import 'login_screen.dart';
import 'supplier_orders_screen.dart';
import 'supplier_completed_screen.dart';

class SupplierItemPrice extends StatefulWidget {
  final Map<String, dynamic> supplierProfile;
  const SupplierItemPrice({super.key, required this.supplierProfile});

  @override
  State<SupplierItemPrice> createState() => _SupplierItemPriceState();
}

class _SupplierItemPriceState extends State<SupplierItemPrice> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  String? expandedItemId;

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
    List<dynamic> categories = widget.supplierProfile['categories'] ?? [];
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchHeader(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('inventory')
                        .where('category', whereIn: categories.isNotEmpty ? categories : ['None'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      var items = snapshot.data!.docs.where((doc) {
                        return doc['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
                      }).toList();

                      if (items.isEmpty) {
                        return const Center(child: Text("No items found in your categories."));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _buildItemTile(items[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => isDrawerOpen = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFEDC9AF), shape: BoxShape.circle),
              child: const Icon(Icons.list, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 15),
          const Text("Item Pricing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: Colors.white,
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: "Search items in your categories...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildItemTile(DocumentSnapshot itemDoc) {
    String stockId = itemDoc.id;
    String name = itemDoc['name'];
    String category = itemDoc['category'];
    bool isExpanded = expandedItemId == stockId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('supplier_prices')
          .doc("${widget.supplierProfile['email']}_$stockId")
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> pricing = {};
        bool hasPricing = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          pricing = snapshot.data!.data() as Map<String, dynamic>;
          hasPricing = pricing['price'] != null;
        }

        double price = (pricing['price'] ?? 0.0).toDouble();
        String unit = pricing['unit'] ?? "box";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPricing)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("RM ${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA65E32))),
                          Text("/$unit", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Text("Not Set", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => expandedItemId = isExpanded ? null : stockId),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showPricingWizard(itemDoc, pricing),
              ),
              if (isExpanded && hasPricing)
                _buildExpandedPricingDetails(pricing),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedPricingDetails(Map<String, dynamic> pricing) {
    String unit = pricing['unit'] ?? "package";
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      width: double.infinity,
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _buildDetailDetailRow("Package Type", pricing['unit'] ?? "box"),
          _buildDetailDetailRow("Standard Delivery", "RM ${pricing['deliveryCharge'] ?? 0} / $unit"),
          _buildDetailDetailRow("Bulk Threshold", "> ${pricing['threshold'] ?? 200} $unit"),
          _buildDetailDetailRow("Bulk Delivery (Fixed)", "RM ${pricing['fixedDelivery'] ?? 300}"),
        ],
      ),
    );
  }

  Widget _buildDetailDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showPricingWizard(DocumentSnapshot itemDoc, Map<String, dynamic> currentPricing) {
    int currentStep = 1;
    final unitCtrl = TextEditingController(text: currentPricing['unit'] ?? "box");
    final priceCtrl = TextEditingController(text: currentPricing['price']?.toString() ?? "");
    final thresholdCtrl = TextEditingController(text: currentPricing['threshold']?.toString() ?? "200");
    final fixedDeliveryCtrl = TextEditingController(text: currentPricing['fixedDelivery']?.toString() ?? "300");
    final deliveryCtrl = TextEditingController(text: currentPricing['deliveryCharge']?.toString() ?? "50");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isLastStep = currentStep == 4;
          String pkg = unitCtrl.text.isEmpty ? "package" : unitCtrl.text;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Text("Set Price: ${itemDoc['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 5),
                Text("Step $currentStep of 4", style: const TextStyle(fontSize: 12, color: Color(0xFFA65E32), fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentStep == 1)
                  _buildWizardField("Package Type (Ex: box, bundle)", unitCtrl, hint: "Ex: box"),
                if (currentStep == 2)
                  _buildWizardField("Price per $pkg (RM)", priceCtrl, isNum: true),
                if (currentStep == 3) ...[
                  const Text("Bulk Delivery Rule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFA65E32))),
                  const SizedBox(height: 15),
                  _buildWizardField("If $pkg are more than (Qty)", thresholdCtrl, isNum: true),
                  _buildWizardField("Fixed Delivery Charge (RM)", fixedDeliveryCtrl, isNum: true),
                ],
                if (currentStep == 4)
                  _buildWizardField("Delivery charge for 1 $pkg (RM)", deliveryCtrl, isNum: true),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('supplier_prices')
                          .doc("${widget.supplierProfile['email']}_${itemDoc.id}")
                          .delete();
                      Navigator.pop(context);
                    },
                    child: const Text("Not Set", style: TextStyle(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA65E32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (isLastStep) {
                        await FirebaseFirestore.instance
                            .collection('supplier_prices')
                            .doc("${widget.supplierProfile['email']}_${itemDoc.id}")
                            .set({
                          'supplierEmail': widget.supplierProfile['email'],
                          'supplierName': widget.supplierProfile['companyName'] ?? widget.supplierProfile['name'],
                          'stockId': itemDoc.id,
                          'stockName': itemDoc['name'],
                          'price': double.tryParse(priceCtrl.text) ?? 0.0,
                          'unit': unitCtrl.text,
                          'qtyPerUnit': 1,
                          'deliveryCharge': double.tryParse(deliveryCtrl.text) ?? 0.0,
                          'threshold': int.tryParse(thresholdCtrl.text) ?? 200,
                          'fixedDelivery': double.tryParse(fixedDeliveryCtrl.text) ?? 300.0,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                        Navigator.pop(context);
                      } else {
                        setDialogState(() => currentStep++);
                      }
                    },
                    child: Text(isLastStep ? "Save" : "Next", style: const TextStyle(color: Colors.white)),
                  ),
                ],
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildWizardField(String label, TextEditingController ctrl, {bool isNum = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
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
              _buildDrawerItem(Icons.home, "Home", onTap: () => Navigator.pop(context)),
              _buildDrawerItem(
                Icons.shopping_cart_outlined,
                "Orders",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierOrdersScreen(
                        supplierProfile: widget.supplierProfile,
                        initialFilter: "Active Order",
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.sell_outlined,
                "Item Price",
                isActive: true,
                onTap: () => setState(() => isDrawerOpen = false),
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
