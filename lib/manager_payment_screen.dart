import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Ensure intl is imported for NumberFormat
import 'dart:convert';
import 'manager_payment_gateway_screen.dart';

class ManagerPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> stockData;
  final String stockId;
  final Map<String, dynamic> managerProfile;
  final int initialQuantity;

  const ManagerPaymentScreen({
    super.key,
    required this.stockData,
    required this.stockId,
    required this.managerProfile,
    this.initialQuantity = 50,
  });

  @override
  State<ManagerPaymentScreen> createState() => _ManagerPaymentScreenState();
}

class _ManagerPaymentScreenState extends State<ManagerPaymentScreen> {
  String searchQuery = "";
  late int quantity;
  final TextEditingController _quantityController = TextEditingController();
  double deliveryCharge = 150.0;
  double taxRate = 0.06;
  bool _isCheckoutExpanded = true;

  // Selected supplier details
  Map<String, dynamic>? selectedSupplier;
  double itemPricePerBox = 20.0;

  @override
  void initState() {
    super.initState();
    quantity = widget.initialQuantity;
    _quantityController.text = quantity.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQty) {
    if (newQty < 0) newQty = 0;
    setState(() {
      quantity = newQty;
      _quantityController.text = quantity.toString();
    });
  }

  double _calculateDelivery() {
    if (selectedSupplier == null) return deliveryCharge;
    
    int threshold = selectedSupplier!['threshold'] ?? 200;
    double stdDelivery = (selectedSupplier!['deliveryCharge'] ?? 50.0).toDouble();
    double fixedBulk = (selectedSupplier!['fixedDelivery'] ?? 300.0).toDouble();

    if (quantity > threshold) {
      return fixedBulk; // Bulk rule: Fixed delivery price
    } else {
      return stdDelivery * quantity; // Standard: charge per unit/package
    }
  }

  @override
  Widget build(BuildContext context) {
    double delivery = _calculateDelivery();
    double subtotal = quantity * itemPricePerBox;
    double tax = subtotal * taxRate;
    double total = subtotal + delivery + tax;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildSupplierList(),
                        SizedBox(height: _isCheckoutExpanded ? 320 : 100), // Dynamic space for sticky bottom pad
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildCheckoutPad(subtotal, tax, total, delivery),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
      decoration: const BoxDecoration(
        color: Color(0xFFD2B49C),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: "Search Supplier Id or Name",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierList() {
    String stockCategory = widget.stockData['category'] ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Supplier')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var allSuppliers = snapshot.data!.docs.map((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return {
            'name': d['companyName'] ?? d['name'] ?? "Unknown Supplier",
            'id': d['staffId'] ?? doc.id.substring(0, 5),
            'email': d['email'],
            'phone': d['phone'] ?? "No Phone Number",
            'categories': d['categories'] ?? [],
            'rating': d['rating'] ?? 0,
            'stockType': widget.stockData['name'],
            'photoBase64': d['photoBase64'] ?? ""
          };
        }).toList();

        // 💡 Filter 1: By Category
        var categoryFiltered = allSuppliers.where((s) {
          List<dynamic> cats = s['categories'] as List<dynamic>;
          return cats.contains(stockCategory);
        }).toList();

        // 💡 Filter 2: By Search Query (ID or Name)
        var filtered = categoryFiltered.where((s) {
          String name = (s['name'] ?? "").toString().toLowerCase();
          String id = (s['id'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery) || id.contains(searchQuery);
        }).toList();

        if (categoryFiltered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  const Icon(Icons.person_search, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    "No suppliers found for category: $stockCategory",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildSyncedSupplierCard(filtered[index]);
          },
        );
      },
    );
  }

  Widget _buildSyncedSupplierCard(Map<String, dynamic> supplier) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('supplier_prices')
          .doc("${supplier['email']}_${widget.stockId}")
          .snapshots(),
      builder: (context, priceSnap) {
        Map<String, dynamic> pricing = {};
        bool hasPriceData = false;
        if (priceSnap.hasData && priceSnap.data!.exists) {
          pricing = priceSnap.data!.data() as Map<String, dynamic>;
          if (pricing.containsKey('price') && pricing['price'] != null && pricing['price'] > 0) {
            hasPriceData = true;
          }
        }

        double pricePerPackage = (pricing['price'] ?? 0.0).toDouble();
        String packageType = pricing['unit'] ?? "box";
        
        bool isSelected = selectedSupplier?['email'] == supplier['email'];
        String photoBase64 = supplier['photoBase64'] ?? "";

        return GestureDetector(
          onTap: () {
            if (!hasPriceData) {
              _notifyMissingPrice();
              return;
            }
            setState(() {
              selectedSupplier = {
                ...supplier,
                ...pricing,
              };
              itemPricePerBox = pricePerPackage;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC98A6B)
                      : Colors.grey.withOpacity(0.2),
                  width: isSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    image: photoBase64.isNotEmpty 
                        ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoBase64.isEmpty 
                      ? const Icon(Icons.business, color: Color(0xFFC98A6B), size: 40)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier['name'], style: const TextStyle(color: Color(0xFF302B2C), fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(widget.stockData['name'] ?? "Stock", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text("Id : ${supplier['id']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      if (supplier['rating'] > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: List.generate(5, (i) => Icon(
                              i < supplier['rating'] ? Icons.star : Icons.star_border,
                              color: i < supplier['rating'] ? Colors.amber : Colors.grey.shade300,
                              size: 14,
                            )),
                          ),
                        ),
                      if (hasPriceData)
                        Text("RM $pricePerPackage/$packageType", style: const TextStyle(color: Color(0xFFC98A6B), fontWeight: FontWeight.w900, fontSize: 16))
                      else
                        const Text("Price not set", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: hasPriceData ? () => _showPricingDetails(supplier, pricing) : _notifyMissingPrice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF302B2C),
                        minimumSize: const Size(60, 25),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Details", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 5),
                    IconButton(
                      onPressed: () => _showContactSupplier(supplier),
                      icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFC98A6B), size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 10),
                    _buildSyncedQuantityControl(supplier['email'], hasPriceData),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showContactSupplier(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Contact ${supplier['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 50, color: Colors.green),
            const SizedBox(height: 15),
            Text(
              supplier['phone'] ?? "No Phone Number",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  void _showPricingDetails(Map<String, dynamic> supplier, Map<String, dynamic> pricing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(supplier['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Item", widget.stockData['name']),
            _buildDetailRow("Price", "RM ${pricing['price'] ?? 20.0} / ${pricing['unit'] ?? 'box'}"),
            _buildDetailRow("Quantity per Pack", "${pricing['qtyPerUnit'] ?? 10}"),
            _buildDetailRow("Delivery/Pack", "RM ${pricing['deliveryCharge'] ?? 50.0}"),
            const Divider(),
            _buildDetailRow("Bulk Rule", "> ${pricing['threshold'] ?? 200} units"),
            _buildDetailRow("Fixed Delivery", "RM ${pricing['fixedDelivery'] ?? 300.0}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSyncedQuantityControl(String supplierEmail, bool hasPrice) {
    bool isSelected = selectedSupplier?['email'] == supplierEmail;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (!hasPrice) {
                _notifyMissingPrice();
                return;
              }
              if (!isSelected) {
                _notifySelectSupplier();
                return;
              }
              _updateQuantity(quantity - 1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.remove_circle,
                  color: isSelected ? const Color(0xFFC98A6B) : Colors.grey,
                  size: 20),
            ),
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: hasPrice && isSelected,
              style: const TextStyle(
                  color: Color(0xFF302B2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                int? newQty = int.tryParse(val);
                if (newQty != null) {
                  setState(() {
                    quantity = newQty;
                  });
                }
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              if (!hasPrice) {
                _notifyMissingPrice();
                return;
              }
              if (!isSelected) {
                _notifySelectSupplier();
                return;
              }
              _updateQuantity(quantity + 1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.add_circle,
                  color: isSelected ? const Color(0xFFC98A6B) : Colors.grey,
                  size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _notifyMissingPrice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("This Supplier did not set the price yet."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _notifySelectSupplier() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please select this supplier first to edit quantity."),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildCheckoutPad(double subtotal, double tax, double total, double currentDelivery) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      decoration: const BoxDecoration(
        color: Color(0xFFD2B49C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isCheckoutExpanded = !_isCheckoutExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Icon(
                _isCheckoutExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          if (_isCheckoutExpanded) ...[
            _buildPriceRow("Subtotal", "RM ${subtotal.toStringAsFixed(0)}"),
            const Divider(color: Colors.black45),
            _buildPriceRow("Delivery Charge", "RM ${currentDelivery.toStringAsFixed(0)}"),
            const Divider(color: Colors.black45),
            _buildPriceRow("Tax (6%)", "RM ${tax.toStringAsFixed(0)}"),
            const Divider(color: Colors.black45),
          ],
          _buildPriceRow("Total", "RM ${total.toStringAsFixed(0)}", isBold: true),
          if (_isCheckoutExpanded) ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _showAddressCard,
              child: const Text("Default Address", style: TextStyle(fontSize: 12, color: Colors.black54, decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Checkout", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddressCard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
            const SizedBox(height: 16),
            const Text(
              "Kota Sri Mutiara, Jalan Sultan Yahya Petra, 15150 Kota Bharu, Kelantan, Malaysia.",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _processCheckout() async {
    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a supplier first")));
      return;
    }

    double delivery = _calculateDelivery();
    double subtotal = quantity * itemPricePerBox;
    double tax = subtotal * taxRate;
    double finalTotal = subtotal + delivery + tax;

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 1. Check Budget Sufficiency
      DocumentReference budgetRef = firestore.collection('financial_metadata').doc('budget');
      DocumentSnapshot budgetSnap = await budgetRef.get();
      double currentBalance = 30000.0;
      if (budgetSnap.exists) {
        currentBalance = (budgetSnap.data() as Map<String, dynamic>)['balance'] ?? 30000.0;
      }

      if (currentBalance < finalTotal) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Insufficient Budget", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Text("The total amount (RM ${finalTotal.toStringAsFixed(2)}) exceeds the current hotel budget (RM ${currentBalance.toStringAsFixed(2)}). Please add funds before purchasing."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
              ],
            ),
          );
        }
        return;
      }

      // 2. Show "Hotel Account" Selection (Locked to Hotel Budget)
      if (mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Payment Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFC98A6B).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.hotel, color: Color(0xFFC98A6B)),
                  ),
                  title: const Text("Grand Renai Hotel Account", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Available Budget: RM ${NumberFormat('#,##0.00').format(currentBalance)}"),
                  trailing: const Icon(Icons.radio_button_checked, color: Color(0xFFC98A6B)),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManagerPaymentGatewayScreen(
                          amount: finalTotal,
                          supplier: selectedSupplier!,
                          stockId: widget.stockId,
                          stockName: widget.stockData['name'] ?? "Unknown",
                          quantity: quantity,
                          managerProfile: widget.managerProfile,
                          isTopUp: false,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF302B2C),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("Confirm & Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
}
