import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class ManagerSupplierProfile extends StatefulWidget {
  const ManagerSupplierProfile({super.key});

  @override
  State<ManagerSupplierProfile> createState() => _ManagerSupplierProfileState();
}

class _ManagerSupplierProfileState extends State<ManagerSupplierProfile> {
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchSection(),
            const SizedBox(height: 10),
            Expanded(child: _buildSupplierList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 15),
          const Text(
            "Suppliers Profile",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF302B2C)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          decoration: const InputDecoration(
            icon: Icon(Icons.search, color: Color(0xFFD2B49C)),
            hintText: "Search Supplier Name or ID",
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Supplier')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading suppliers"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var suppliers = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['companyName'] ?? data['name'] ?? "").toString().toLowerCase();
          String id = (data['staffId'] ?? doc.id).toString().toLowerCase();
          return name.contains(searchQuery) || id.contains(searchQuery);
        }).toList();

        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text("No suppliers found", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            var data = suppliers[index].data() as Map<String, dynamic>;
            String docId = suppliers[index].id;
            return _buildSupplierCard(data, docId);
          },
        );
      },
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> data, String docId) {
    String name = data['companyName'] ?? data['name'] ?? "Unknown Supplier";
    String id = data['staffId'] ?? "N/A";
    List<dynamic> categories = data['categories'] ?? [];
    String photoBase64 = data['photoBase64'] ?? "";
    int rating = data['rating'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(15),
                    image: photoBase64.isNotEmpty
                        ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoBase64.isEmpty
                      ? const Icon(Icons.business, size: 40, color: Color(0xFFD2B49C))
                      : null,
                ),
                const SizedBox(width: 15),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF302B2C)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID: $id",
                        style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Supplies Categories:",
                        style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categories.map((cat) => _buildCategoryTag(cat.toString())).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rating Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Supplier Performance",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                _buildStarRating(rating, docId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD2B49C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFFA65E32), fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStarRating(int currentRating, String docId) {
    return Row(
      children: List.generate(5, (index) {
        int starValue = index + 1;
        return GestureDetector(
          onTap: () async {
            await FirebaseFirestore.instance.collection('users').doc(docId).update({
              'rating': starValue,
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              starValue <= currentRating ? Icons.star : Icons.star_border,
              color: starValue <= currentRating ? Colors.amber : Colors.grey.shade300,
              size: 26,
            ),
          ),
        );
      }),
    );
  }
}
