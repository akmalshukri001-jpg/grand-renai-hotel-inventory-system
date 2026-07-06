import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class HousekeepingItemPage extends StatefulWidget {
  final String stockId;
  final Map<String, dynamic> stockData;
  final Map<String, dynamic> housekeepingProfile;
  final int initialQty;

  const HousekeepingItemPage({
    super.key,
    required this.stockId,
    required this.stockData,
    required this.housekeepingProfile,
    this.initialQty = 0,
  });

  @override
  State<HousekeepingItemPage> createState() => _HousekeepingItemPageState();
}

class _HousekeepingItemPageState extends State<HousekeepingItemPage> {
  late int quantity;

  @override
  void initState() {
    super.initState();
    quantity = widget.initialQty;
  }

  void _updateQuantity(int newQty) {
    if (newQty < 0) return;
    
    int availableQty = widget.stockData['availableQty'] ?? 0;
    if (newQty > availableQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Only $availableQty units available in stock."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newQty > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Staff cannot get more than 5 units per day."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      quantity = newQty;
    });
  }

  @override
  Widget build(BuildContext context) {
    String photoBase64 = widget.stockData['photoBase64'] ?? "";
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.stockData['name'] ?? "Item Details", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                        image: photoBase64.isNotEmpty
                            ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: photoBase64.isEmpty ? const Icon(Icons.inventory_2, size: 80, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildDetailSection("Location", widget.stockData['location'] ?? "Not Specified", Icons.place),
                  _buildDetailSection("Category", widget.stockData['category'] ?? "General", Icons.category),
                  _buildDetailSection("Available Quantity", "${widget.stockData['availableQty'] ?? 0} units", Icons.analytics),
                  const SizedBox(height: 20),
                  const Text(
                    "Item Description",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "This item is part of the standard hotel inventory for housekeeping staff. Please ensure accurate tracking of stock usage.",
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          _buildAddToCartSticky(),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFD2B49C).withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF8D5B3E), size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAddToCartSticky() {
    int availableQty = widget.stockData['availableQty'] ?? 0;
    bool isOutOfStock = availableQty <= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: isOutOfStock ? null : () => _updateQuantity(quantity - 1), 
                      icon: const Icon(Icons.remove_circle_outline)
                    ),
                    Text("$quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: isOutOfStock ? null : () => _updateQuantity(quantity + 1), 
                      icon: const Icon(Icons.add_circle_outline)
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isOutOfStock ? Colors.grey : const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: isOutOfStock ? null : () {
                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a quantity greater than 0."), backgroundColor: Colors.orange)
                  );
                  return;
                }
                Navigator.pop(context, {'qty': quantity});
              },
              child: Text(
                isOutOfStock ? "Unavailable (Out of Stock)" : "Add to Cart", 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          )
        ],
      ),
    );
  }
}
