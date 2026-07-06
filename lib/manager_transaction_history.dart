import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class ManagerTransactionHistoryScreen extends StatefulWidget {
  final String title;
  final DateTime startDate;

  const ManagerTransactionHistoryScreen({
    super.key,
    required this.title,
    required this.startDate,
  });

  @override
  State<ManagerTransactionHistoryScreen> createState() => _ManagerTransactionHistoryScreenState();
}

class _ManagerTransactionHistoryScreenState extends State<ManagerTransactionHistoryScreen> {
  StreamSubscription? _paymentsSubscription;
  StreamSubscription? _fundsSubscription;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToTransactions();
  }

  @override
  void dispose() {
    _paymentsSubscription?.cancel();
    _fundsSubscription?.cancel();
    super.dispose();
  }

  void _listenToTransactions() {
    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('timestamp', isGreaterThanOrEqualTo: widget.startDate)
        .snapshots();

    final fundsStream = FirebaseFirestore.instance
        .collection('funds_history')
        .where('timestamp', isGreaterThanOrEqualTo: widget.startDate)
        .snapshots();

    List<Map<String, dynamic>> currentPayments = [];
    List<Map<String, dynamic>> currentFunds = [];

    void updateList() {
      List<Map<String, dynamic>> combined = [];
      combined.addAll(currentPayments);
      combined.addAll(currentFunds);
      
      combined.sort((a, b) {
        Timestamp t1 = a['timestamp'] ?? Timestamp.now();
        Timestamp t2 = b['timestamp'] ?? Timestamp.now();
        return t2.compareTo(t1);
      });

      if (mounted) {
        setState(() {
          _transactions = combined;
          _isLoading = false;
        });
      }
    }

    _paymentsSubscription = paymentsStream.listen((snap) {
      currentPayments = snap.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['type'] = 'payment';
        return data;
      }).toList();
      updateList();
    });

    _fundsSubscription = fundsStream.listen((snap) {
      currentFunds = snap.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['type'] = 'funds';
        return data;
      }).toList();
      updateList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC98A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text("No transactions found.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final data = _transactions[index];
                      return data['type'] == 'payment' 
                        ? _buildPurchaseItem(context, data)
                        : _buildFundsItem(context, data);
                    },
                  ),
          ),
          _buildReportButtons(context),
        ],
      ),
    );
  }

  Widget _buildPurchaseItem(BuildContext context, Map<String, dynamic> data) {
    Timestamp ts = data['timestamp'] ?? Timestamp.now();
    DateTime date = ts.toDate();
    double total = (data['totalAmount'] ?? 0).toDouble();

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Purchase", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    Text(data['stockName'] ?? "Stock", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
              ),
              Text(
                "- RM ${NumberFormat('#,##0.00').format(total)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.redAccent),
              ),
            ],
          ),
          const Divider(height: 25),
          _buildDetailRow(Icons.business, "Supplier", data['supplierName'] ?? "N/A"),
          _buildDetailRow(Icons.shopping_cart_outlined, "Quantity", "${data['quantity']} box"),
          _buildDetailRow(Icons.person_outline, "Requested by", data['requestedBy'] ?? "Supervisor"),
          _buildDetailRow(Icons.assignment_ind_outlined, "Approved by", data['processedBy'] ?? "Manager"),
          _buildDetailRow(Icons.calendar_today, "Date", DateFormat('dd MMM yyyy, hh:mm a').format(date)),
        ],
      ),
    );
  }

  Widget _buildFundsItem(BuildContext context, Map<String, dynamic> data) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Top-up", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    const Text("Funds Added", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
              ),
              Text(
                "+ RM ${NumberFormat('#,##0.00').format(amount)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green),
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
          const SizedBox(height: 5),
          _buildDetailRow(Icons.calendar_today, "Date", DateFormat('dd MMM yyyy, hh:mm a').format(date)),
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

  Widget _buildReportButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _generatePDFReport(context),
          icon: const Icon(Icons.download),
          label: const Text("Download Transaction Report"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC98A6B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePDFReport(BuildContext context) async {
    try {
      if (_transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records to export.")));
        return;
      }

      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = DateFormat('dd MMMM yyyy, hh:mm a').format(now);

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
                    pw.Text(widget.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Grand Renai", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Generated on: $formattedDate"),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Type', 'Details', 'Amount (RM)', 'By'],
                data: _transactions.map((data) {
                  DateTime date = (data['timestamp'] as Timestamp).toDate();
                  String formattedDateStr = DateFormat('dd/MM/yy HH:mm').format(date);
                  
                  String type = data['type'] == 'payment' ? 'Purchase' : 'Top-up';
                  String details = data['type'] == 'payment' 
                      ? "${data['stockName']} (${data['supplierName']})"
                      : "Funds Added";
                  double amount = data['type'] == 'payment' ? (data['totalAmount'] ?? 0).toDouble() : (data['amountAdded'] ?? 0).toDouble();
                  String by = data['type'] == 'payment' ? (data['processedBy'] ?? '') : (data['managerName'] ?? '');
                  
                  return [
                    formattedDateStr,
                    type,
                    details,
                    NumberFormat('#,##0.00').format(amount),
                    by,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerLeft,
                },
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = "${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf";

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: '$fileName');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report Generated!"), backgroundColor: Colors.green),
        );
      } else {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final file = File("${directory.path}/$fileName");
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: '$fileName');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Report saved to local storage."),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await Printing.sharePdf(bytes: bytes, filename: '$fileName');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
}
