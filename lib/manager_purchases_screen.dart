import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';
import 'team_screen.dart';
import 'manager_payment_screen.dart';
import 'manager_financial_screen.dart';
import 'manager_stock_tracking.dart';

class ManagerPurchasesScreen extends StatefulWidget {
  final Map<String, dynamic> managerProfile;
  const ManagerPurchasesScreen({super.key, required this.managerProfile});

  @override
  State<ManagerPurchasesScreen> createState() => _ManagerPurchasesScreenState();
}

class _ManagerPurchasesScreenState extends State<ManagerPurchasesScreen> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  String currentFilter = "All"; // All, Requested, Completed
  File? _profileImage;
  String hotelLogoUrl = ""; // Holds the Base64 data for the Hotel Logo

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
    _listenToHotelLogoData();
  }

  void _listenToHotelLogoData() {
    FirebaseFirestore.instance
        .collection('hotel_metadata')
        .doc('logo')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        if (mounted) {
          setState(() {
            hotelLogoUrl = data['imageUrl'] ?? '';
          });
        }
      }
    });
  }

  Future<void> _loadSavedProfileImage() async {
    final String uniqueId = widget.managerProfile['username'] ?? widget.managerProfile['email'] ?? 'default_user';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString('manager_profile_path_$uniqueId');

    if (imagePath != null && imagePath.isNotEmpty) {
      File savedFile = File(imagePath);
      if (await savedFile.exists()) {
        setState(() {
          _profileImage = savedFile;
        });
      }
    }
  }

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.managerProfile['email'];
    if (email.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      });
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSearchSection(),
                        const SizedBox(height: 25),
                        _buildFilterRow(),
                        const SizedBox(height: 20),
                        _buildPurchaseGrid(),
                        const SizedBox(height: 40),
                      ],
                    ),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.managerProfile['email']).snapshots(),
      builder: (context, snapshot) {
        String photoBase64 = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          photoBase64 = (snapshot.data!.data() as Map<String, dynamic>)['photoBase64'] ?? "";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.list, color: Colors.black87, size: 32),
                onPressed: () => setState(() => isDrawerOpen = true),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                        image: hotelLogoUrl.isNotEmpty
                            ? DecorationImage(image: MemoryImage(base64Decode(hotelLogoUrl)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: hotelLogoUrl.isEmpty
                          ? const Icon(Icons.hotel, color: Color(0xFFA65E32), size: 20)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        "Grand Renai Hotel Inventory",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                          color: Color(0xFF302B2C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile)),
                  );
                  _loadSavedProfileImage();
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: photoBase64.isNotEmpty
                          ? MemoryImage(base64Decode(photoBase64))
                          : (_profileImage != null ? FileImage(_profileImage!) : null),
                      child: (photoBase64.isEmpty && _profileImage == null) ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const Text("Manager", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildSearchSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
      decoration: const BoxDecoration(
        color: Color(0xFFD2B49C),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(
        children: [
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
                  hintText: "Search Stock",
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

  Widget _buildFilterRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('stock_requests').where('status', isEqualTo: 'Pending').snapshots(),
      builder: (context, snapshot) {
        bool hasRequests = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterButton("All"),
              _buildFilterButton("Requested", showDot: hasRequests),
              _buildFilterButton("Completed"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(String label, {bool showDot = false}) {
    bool isSelected = currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD2B49C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (showDot)
              Positioned(
                top: -2,
                right: -8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
      builder: (context, inventorySnapshot) {
        if (!inventorySnapshot.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('stock_requests').snapshots(),
          builder: (context, requestsSnapshot) {
            var items = inventorySnapshot.data!.docs;
            var requests = requestsSnapshot.hasData ? requestsSnapshot.data!.docs : [];

            // 1. Filter inventory items based on search query
            var filteredItems = items.where((doc) {
              String name = (doc['name'] ?? "").toString().toLowerCase();
              return name.contains(searchQuery);
            }).toList();

            // 2. Map inventory items to their request status
            List<Map<String, dynamic>> displayList = [];
            for (var doc in filteredItems) {
              var data = doc.data() as Map<String, dynamic>;
              var itemRequests = requests.where((r) => r['stockId'] == doc.id).toList();
              
              // 💡 Fix: Sort requests by timestamp (Latest first) to get accurate status
              itemRequests.sort((a, b) {
                Timestamp? tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                Timestamp? tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (tA == null) return -1;
                if (tB == null) return 1;
                return tB.compareTo(tA);
              });

              String status = "Purchased"; // Default
              String requestedBy = "System";
              int requestedQty = 50;

              if (itemRequests.isNotEmpty) {
                // 💡 Fix: Prioritize 'Pending' if multiple requests exist, otherwise take latest
                var pendingReq = itemRequests.where((r) => r['status'] == 'Pending').toList();
                var activeReq = pendingReq.isNotEmpty ? pendingReq.first : itemRequests.first;

                status = activeReq['status'] ?? "Pending";
                requestedBy = activeReq['supervisorName'] ?? "Supervisor";
                requestedQty = activeReq['requestedQty'] ?? 50;
              }

              // Apply Tab Filters
              if (currentFilter == "Requested" && status != "Pending") continue;
              if (currentFilter == "Completed" && status != "Completed") continue;

              displayList.add({
                'id': doc.id,
                'data': data,
                'status': status,
                'requestedBy': requestedBy,
                'requestedQty': requestedQty,
              });
            }

            if (displayList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text("No items found for $currentFilter", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.75,
              ),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                var item = displayList[index];
                return _buildStockCard(
                  item['data'], 
                  item['id'], 
                  item['status'], 
                  item['requestedBy'], 
                  item['requestedQty']
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStockCard(Map<String, dynamic> data, String stockId, String status, String requester, int initialQty) {
    String photoBase64 = data['photoBase64'] ?? "";
    Color statusColor = status == "Pending" || status == "Requested" ? Colors.redAccent : Colors.blueGrey.shade100;
    if (status == "Completed") statusColor = Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD2B49C).withOpacity(0.4),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                image: photoBase64.isNotEmpty
                    ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                    : null,
              ),
              child: photoBase64.isEmpty ? const Icon(Icons.inventory_2, color: Colors.grey) : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['name'] ?? "Stock",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                "${data['availableQty']}/${data['totalQty']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10)),
            child: Text(status, style: TextStyle(color: status == "Purchased" ? Colors.black87 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text("By $requester\n(Supervisors)", style: const TextStyle(fontSize: 9, color: Colors.black54, height: 1.1)),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerPaymentScreen(
                        stockData: data,
                        stockId: stockId,
                        managerProfile: widget.managerProfile,
                        initialQuantity: initialQty,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              )
            ],
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
              _buildDrawerItem(Icons.shopping_bag, "Purchases", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.analytics,
                "Financial",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerFinancialScreen(managerProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.track_changes,
                "Stock Tracking",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerStockTracking(managerProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.people,
                "Team",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamScreen(currentUserProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.settings,
                "Settings",
                onTap: () async {
                  setState(() => isDrawerOpen = false);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile),
                    ),
                  );
                  _loadSavedProfileImage();
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
