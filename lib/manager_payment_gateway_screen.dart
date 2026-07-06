import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'manager_stock_tracking.dart';
import 'manager_financial_screen.dart';
import 'manager_dashboard.dart';
import 'profile_settings_screen.dart'; // Import Profile Settings

class ManagerPaymentGatewayScreen extends StatefulWidget {
  final double amount;
  final Map<String, dynamic>? supplier;
  final String? stockId;
  final String? stockName;
  final int? quantity;
  final Map<String, dynamic> managerProfile;
  final bool isTopUp;

  const ManagerPaymentGatewayScreen({
    super.key,
    required this.amount,
    this.supplier,
    this.stockId,
    this.stockName,
    this.quantity,
    required this.managerProfile,
    this.isTopUp = false,
  });

  @override
  State<ManagerPaymentGatewayScreen> createState() => _ManagerPaymentGatewayScreenState();
}

class _ManagerPaymentGatewayScreenState extends State<ManagerPaymentGatewayScreen> {
  bool _isProcessing = false;
  bool _isCompleted = false;
  String _statusMessage = "Connecting to Secure Gateway...";

  @override
  void initState() {
    super.initState();
    _startPaymentSimulation();
  }

  void _startPaymentSimulation() {
    setState(() {
      _isProcessing = true;
    });

    // Step 1: Initializing
    Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _statusMessage = "Verifying Hotel Budget...");
    });

    // Step 2: Processing Payment
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = "Authorizing Transaction...");
    });

    // Step 3: Finalizing with Database Update
    Timer(const Duration(seconds: 5), () async {
      await _finalizeTransaction();
    });
  }

  Future<void> _finalizeTransaction() async {
    try {
      // Check for profile completeness first (as part of the simulation)
      String phone = widget.managerProfile['phone'] ?? "";
      String address = widget.managerProfile['address'] ?? "";

      if (phone.isEmpty || address.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isCompleted = false;
            _statusMessage = "Payment Unsuccessful!";
          });
        }
        return;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String transactionId = "TXN${DateTime.now().millisecondsSinceEpoch}";
      double previousBalance = 0.0;
      double newBalance = 0.0;
      
      // 1. Update Hotel Budget
      DocumentReference budgetRef = firestore.collection('financial_metadata').doc('budget');
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot budgetSnap = await transaction.get(budgetRef);
        previousBalance = 30000.0;
        if (budgetSnap.exists && budgetSnap.data() != null) {
          previousBalance = (budgetSnap.data() as Map<String, dynamic>)['balance']?.toDouble() ?? 30000.0;
        }
        newBalance = widget.isTopUp ? (previousBalance + widget.amount) : (previousBalance - widget.amount);
        transaction.set(budgetRef, {'balance': newBalance}, SetOptions(merge: true));
      });

      if (widget.isTopUp) {
        // Log to Funds History for Top-up
        await firestore.collection('funds_history').add({
          'transactionId': transactionId,
          'managerName': widget.managerProfile['name'],
          'managerId': widget.managerProfile['staffId'] ?? 'MGR-UNKNOWN',
          'amountAdded': widget.amount,
          'previousBudget': previousBalance,
          'newBudget': newBalance,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Log for Purchase
        var requests = await firestore
            .collection('stock_requests')
            .where('stockId', isEqualTo: widget.stockId)
            .where('status', isEqualTo: 'Pending')
            .get();

        String supervisorName = "Supervisor";
        for (var doc in requests.docs) {
          supervisorName = doc.data()['supervisorName'] ?? "Supervisor";
          await doc.reference.update({
            'status': 'Purchased',
            'approvedBy': widget.managerProfile['name'],
            'orderedQty': widget.quantity,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        await firestore.collection('payments').add({
          'stockId': widget.stockId,
          'stockName': widget.stockName,
          'stockCategory': widget.supplier?['categories']?.isNotEmpty == true ? widget.supplier!['categories'][0] : 'General',
          'supplierName': widget.supplier?['name'],
          'supplierEmail': widget.supplier?['email'],
          'quantity': widget.quantity,
          'totalAmount': widget.amount,
          'timestamp': FieldValue.serverTimestamp(),
          'processedBy': widget.managerProfile['name'],
          'requestedBy': supervisorName,
          'status': 'Purchased'
        });
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCompleted = true;
          _statusMessage = "Payment Successful!";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Payment Failed: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Brand
              const Text("GRAND RENAI", style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300, fontSize: 18)),
              const Text("SECURE CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
              const SizedBox(height: 60),

              // Animated Status Icon
              if (_isProcessing)
                const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3)
              else if (_isCompleted)
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 100)
              else
                const Icon(Icons.error_outline, color: Colors.red, size: 100),

              const SizedBox(height: 40),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                "Transaction ID: GRH-${DateTime.now().millisecondsSinceEpoch}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 60),
              
              // Receipt Summary Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    if (widget.isTopUp) ...[
                      _buildReceiptRow("Type", "Budget Top-up"),
                      _buildReceiptRow("Manager", widget.managerProfile['name']),
                      _buildReceiptRow("Manager ID", widget.managerProfile['staffId'] ?? 'N/A'),
                    ] else ...[
                      _buildReceiptRow("Supplier", widget.supplier?['name'] ?? 'N/A'),
                      _buildReceiptRow("Item", widget.stockName ?? 'N/A'),
                      _buildReceiptRow("Quantity", "${widget.quantity} Units"),
                    ],
                    const Divider(height: 30),
                    _buildReceiptRow(widget.isTopUp ? "Amount" : "Total Paid", "RM ${widget.amount.toStringAsFixed(2)}", isTotal: true),
                  ],
                ),
              ),

              const SizedBox(height: 60),
              if (_isCompleted)
                ElevatedButton(
                  onPressed: () {
                    // Navigate based on transaction type
                    if (widget.isTopUp) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => ManagerFinancialScreen(
                            managerProfile: widget.managerProfile,
                            successTransaction: {
                              'txnId': "TXN${DateTime.now().millisecondsSinceEpoch}",
                              'time': DateTime.now(),
                            },
                          ),
                        ),
                        (route) => route.isFirst,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => ManagerStockTracking(managerProfile: widget.managerProfile),
                        ),
                        (route) => route.isFirst,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                      widget.isTopUp ? "Return to Financials" : "Track My Order",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else if (!_isProcessing)
                ElevatedButton(
                  onPressed: () {
                    // Show popup alert first as requested
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Profile Incomplete",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        content: const Text(
                            "Please complete your Phone Number and Address in Settings before proceeding with any transactions."),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx); // Close Dialog
                              // Redirect to Profile Settings Screen
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => ProfileSettingsScreen(
                                      userProfile: widget.managerProfile),
                                ),
                                (route) => route.isFirst,
                              );
                            },
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                      widget.isTopUp
                          ? "Return to Financials"
                          : "Return to Homepage",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isTotal ? Colors.black : Colors.grey, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: isTotal ? Colors.blueAccent : Colors.black87, fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold, fontSize: isTotal ? 18 : 14)),
      ],
    );
  }
}
