import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SupervisorRequestStock extends StatefulWidget {
  final String stockId;
  final Map<String, dynamic> stockData;
  final Map<String, dynamic> supervisorProfile;

  const SupervisorRequestStock({
    super.key,
    required this.stockId,
    required this.stockData,
    required this.supervisorProfile,
  });

  @override
  State<SupervisorRequestStock> createState() => _SupervisorRequestStockState();
}

class _SupervisorRequestStockState extends State<SupervisorRequestStock> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isPrinting = false;

  Future<void> _submitRequest() async {
    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter quantity")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('stock_requests').add({
        'stockId': widget.stockId,
        'stockName': widget.stockData['name'],
        'requestedQty': int.tryParse(_quantityController.text) ?? 0,
        'notes': _notesController.text,
        'supervisorName': widget.supervisorProfile['name'],
        'supervisorId': widget.supervisorProfile['staffId'],
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stock request submitted successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Stock"),
        content: Text("Are you sure you want to delete '${widget.stockData['name']}'? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                // 1. Delete from Firestore
                await FirebaseFirestore.instance.collection('inventory').doc(widget.stockId).delete();

                // 2. Clean up any orphaned requests for this item
                var orphanedRequests = await FirebaseFirestore.instance
                    .collection('stock_requests')
                    .where('stockId', isEqualTo: widget.stockId)
                    .get();
                for (var r in orphanedRequests.docs) {
                  await r.reference.delete();
                }

                // 3. Log the action
                await FirebaseFirestore.instance.collection('stock_logs').add({
                  'action': "DELETED",
                  'itemName': widget.stockData['name'],
                  'totalQty': widget.stockData['totalQty'] ?? 0,
                  'availableQty': widget.stockData['availableQty'] ?? 0,
                  'staffId': widget.supervisorProfile['staffId'] ?? 'SUP-UNKNOWN',
                  'staffName': widget.supervisorProfile['name'] ?? 'Supervisor',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to inventory screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("'${widget.stockData['name']}' deleted successfully."), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String photoBase64 = widget.stockData['photoBase64'] ?? "";
    String stockId = widget.stockId;
    String stockName = widget.stockData['name'] ?? "Unknown";

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Stock Details & Request", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC98A6B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isPrinting ? null : _printSingleBarcode,
            tooltip: "Print Label",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          image: photoBase64.isNotEmpty
                              ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                              : null,
                        ),
                        child: photoBase64.isEmpty ? const Icon(Icons.inventory_2, size: 40, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stockName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(widget.stockData['location'] ?? "No Location", style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 5),
                            Text("Current: ${widget.stockData['availableQty']} / ${widget.stockData['totalQty']}", 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC98A6B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  // Professional Barcode Section
                  Column(
                    children: [
                      const Text("Item QR Label", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _printSingleBarcode,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                          ),
                          child: BarcodeWidget(
                            barcode: Barcode.qrCode(),
                            data: stockId,
                            width: 130,
                            height: 130,
                            drawText: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(stockId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF302B2C))),
                      const Text("Click to print this label", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text("Request Replenishment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Quantity Needed",
                prefixIcon: const Icon(Icons.add_shopping_cart, color: Color(0xFFC98A6B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Notes (Optional)",
                prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFFC98A6B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _isSubmitting ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Delete Item", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF302B2C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _isSubmitting ? null : _submitRequest,
                      child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSingleBarcode() async {
    setState(() => _isPrinting = true);
    try {
      final pdf = pw.Document();
      final String name = widget.stockData['name'] ?? "Unknown";
      final String id = widget.stockId;

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 40 * PdfPageFormat.mm), // Small sticker size
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 2),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: id,
                    width: 25 * PdfPageFormat.mm,
                    height: 25 * PdfPageFormat.mm,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(id, style: const pw.TextStyle(fontSize: 6)),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Label_$name.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Print failed: $e")));
    } finally {
      setState(() => _isPrinting = false);
    }
  }
}
