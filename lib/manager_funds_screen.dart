import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'manager_payment_gateway_screen.dart';
import 'manager_financial_screen.dart';

class ManagerFundsScreen extends StatefulWidget {
  final Map<String, dynamic> managerProfile;
  const ManagerFundsScreen({super.key, required this.managerProfile});

  @override
  State<ManagerFundsScreen> createState() => _ManagerFundsScreenState();
}

class _ManagerFundsScreenState extends State<ManagerFundsScreen> {
  final TextEditingController _amountController = TextEditingController();
  double currentBudget = 30000.0;
  double newBudget = 30000.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _listenToBudget();
    _amountController.addListener(_calculateNewBudget);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _listenToBudget() {
    FirebaseFirestore.instance
        .collection('financial_metadata')
        .doc('budget')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          // Sync with the same logic as Financial Screen
          currentBudget = (snap.data()?['balance'] ?? 30000.0).toDouble();
          _calculateNewBudget();
        });
      }
    });
  }

  void _calculateNewBudget() {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      newBudget = currentBudget + amount;
    });
  }

  Future<void> _processTransfer() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount")));
      return;
    }

    _showPaymentMethodDialog(amount);
  }

  int _selectedPaymentIndex = 0;

  void _showPaymentMethodDialog(double amount) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildPaymentOption(0, Icons.account_balance, "Online Banking (FPX)", "Select Bank", setModalState),
              _buildPaymentOption(1, Icons.credit_card, "Credit/Debit Card", "**** 4421", setModalState),
              _buildPaymentOption(2, Icons.account_balance_wallet, "e-Wallet", "Touch 'n Go, GrabPay", setModalState),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Sheet
                  _navigateToGateway(amount);
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
      ),
    );
  }

  Widget _buildPaymentOption(int index, IconData icon, String title, String subtitle, StateSetter setModalState) {
    bool isSelected = _selectedPaymentIndex == index;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC98A6B).withOpacity(0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFC98A6B)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? const Color(0xFFC98A6B) : Colors.grey,
        size: 20,
      ),
      onTap: () {
        setModalState(() {
          _selectedPaymentIndex = index;
        });
      },
    );
  }

  void _navigateToGateway(double amount) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerPaymentGatewayScreen(
          amount: amount,
          managerProfile: widget.managerProfile,
          isTopUp: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Add Funds", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC98A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadOnlyField("Manager Name", widget.managerProfile['name'] ?? 'N/A'),
            _buildReadOnlyField("Manager Id", widget.managerProfile['staffId'] ?? 'N/A'),
            _buildReadOnlyField("Previous Budget", "RM ${NumberFormat('#,##0.00').format(currentBudget)}"),
            const SizedBox(height: 10),
            const Text("Budget Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixText: "RM ",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                hintText: "0.00",
              ),
            ),
            const SizedBox(height: 20),
            _buildReadOnlyField("New Budget", "RM ${NumberFormat('#,##0.00').format(newBudget)}", isHighlight: true),
            _buildReadOnlyField("Date", DateFormat('dd MMMM yyyy').format(DateTime.now())),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF302B2C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Transfer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isHighlight ? const Color(0xFFD2B49C).withOpacity(0.3) : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFFB06138) : Colors.black87)),
        ),
      ],
    );
  }
}
