import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManagerFundsHistoryScreen extends StatelessWidget {
  const ManagerFundsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Funds History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC98A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('funds_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text("No funds records found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildHistoryItem(context, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> data) {
    Timestamp ts = data['timestamp'] ?? Timestamp.now();
    DateTime date = ts.toDate();
    double amount = (data['amountAdded'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Amount Added", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(
                    "RM ${NumberFormat('#,##0.00').format(amount)}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(DateFormat('hh:mm a').format(date), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const Divider(height: 25),
          _buildDetailRow(Icons.person_outline, "Added by", data['managerName'] ?? "Manager"),
          _buildDetailRow(Icons.badge_outlined, "Manager ID", data['managerId'] ?? "N/A"),
          _buildDetailRow(Icons.receipt_long_outlined, "Transaction ID", data['transactionId'] ?? "N/A"),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Previous: RM ${NumberFormat('#,##0.00').format(data['previousBudget'] ?? 0)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text("New Balance: RM ${NumberFormat('#,##0.00').format(data['newBudget'] ?? 0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label : ", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))),
        ],
      ),
    );
  }
}
