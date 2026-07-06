import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';
import 'supplier_item_price.dart';
import 'supplier_orders_screen.dart';
import 'supplier_completed_screen.dart';
// import 'supplier_item_price.dart';
import 'supplier_orders_screen.dart';
// import 'supplier_completed_screen.dart';

class SupplierDashboard extends StatefulWidget {
  final Map<String, dynamic> supplierProfile;
  const SupplierDashboard({super.key, required this.supplierProfile});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  String eventTitle = "Loading Event...";
  String eventImageUrl = "";
  String hotelLogoUrl = "";
  bool isDrawerOpen = false;
  File? _profileImage;
  Timer? _heartbeatTimer; //Heratbeattimer



  // Stats variables (Read-only for Supplier)
  String bestStaffName = "Junoh Hassan";
  String bestStaffMonth = "Jan 2026";
  int towelStockPercentage = 15;

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
    _listenToLiveEventData();
    _listenToHotelLogoData();
    _updateUserStatus(true);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updateUserStatus(true);
    });
  }


  Future<void> _updateUserStatus(bool isAvailable) async {
    final String? email = widget.supplierProfile['email']?.toString().toLowerCase();
    if (email != null && email.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  void didUpdateWidget(covariant SupplierDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supplierProfile['username'] != widget.supplierProfile['username']) {
      _loadSavedProfileImage();
      _listenToLiveEventData();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel(); // 👈 Stop timer
    super.dispose();
  }

  void _listenToLiveEventData() {
    FirebaseFirestore.instance
        .collection('events_metadata')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        setState(() {
          eventTitle = data['title'] ?? 'No Active Event Scheduled';
          eventImageUrl = data['imageUrl'] ?? '';
        });
      }
    });
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
    if (kIsWeb) return; // Skip local file access on web

    final String uniqueId = widget.supplierProfile['username'] ?? widget.supplierProfile['email'] ?? 'default_user';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString('manager_profile_path_$uniqueId');

    if (imagePath != null && imagePath.isNotEmpty) {
      File savedFile = File(imagePath);
      if (await savedFile.exists()) {
        setState(() {
          _profileImage = savedFile;
        });
        return;
      }
    }
    setState(() {
      _profileImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildHeaderRow(),
                    const SizedBox(height: 20),
                    _buildTitleBanner(),
                    const SizedBox(height: 25),
                    _buildLiveEventSection(),
                    const SizedBox(height: 25),
                    _buildTwinStatsRow(),
                    const SizedBox(height: 25),
                    _buildOrganizationChartSection(),
                    const SizedBox(height: 30),
                    _buildScanButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  Widget _buildLiveEventSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events_metadata').doc('current').snapshots(),
      builder: (context, snapshot) {
        String title = eventTitle;
        String image = eventImageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          title = data['title'] ?? "No Active Events";
          image = data['imageUrl'] ?? "";
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Latest Events", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.amber.shade800,
                image: image.isNotEmpty
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(image)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (image.isEmpty)
                    const Center(
                      child: Icon(Icons.event_available, color: Colors.white, size: 50),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
              _buildDrawerItem(Icons.home, "Home", isActive: true),
              _buildDrawerItem(
                Icons.shopping_cart_outlined,
                "Orders",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
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
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierItemPrice(
                        supplierProfile: widget.supplierProfile,
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.assignment_turned_in_outlined,
                "Completed",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
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
                  final updatedProfile = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(userProfile: widget.supplierProfile),
                    ),
                  );
                  if (updatedProfile != null) {
                    setState(() {
                      _loadSavedProfileImage();
                    });
                  }
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

  Widget _buildHeaderRow() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.supplierProfile['email']).snapshots(),
      builder: (context, snapshot) {
        String photoBase64 = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          photoBase64 = (snapshot.data!.data() as Map<String, dynamic>)['photoBase64'] ?? "";
        }

        Widget profileImgWidget;
        if (photoBase64.isNotEmpty) {
          profileImgWidget = CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: MemoryImage(base64Decode(photoBase64)),
          );
        } else {
          profileImgWidget = CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.white),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.list, color: Colors.black87, size: 32),
              onPressed: () => setState(() => isDrawerOpen = true),
            ),
            // HOTEL LOGO CIRCLE (View only for Supplier)
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
                image: hotelLogoUrl.isNotEmpty 
                  ? DecorationImage(image: MemoryImage(base64Decode(hotelLogoUrl)), fit: BoxFit.cover)
                  : null,
                ),
                child: hotelLogoUrl.isEmpty 
                  ? const Icon(Icons.hotel, color: Color(0xFFA65E32), size: 35)
                  : null,
            ),
            GestureDetector(
              onTap: () async {
                final updatedProfile = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(userProfile: widget.supplierProfile),
                  ),
                );
                if (updatedProfile != null) {
                  setState(() {
                    _loadSavedProfileImage();
                  });
                }
              },
              child: Column(
                children: [
                  profileImgWidget,
                  const SizedBox(height: 2),
                  const Text("Supplier", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        );
      }
    );
  }

  Widget _buildTitleBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.black87, width: 1.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Grand Renai Hotel Inventory',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTwinStatsRow() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('awards').doc('monthly_best').snapshots(),
      builder: (context, awardSnapshot) {
        String name = bestStaffName;
        String month = bestStaffMonth;
        String photoBase64 = "";

        if (awardSnapshot.hasData && awardSnapshot.data!.exists) {
          final data = awardSnapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? bestStaffName;
          month = data['month'] ?? bestStaffMonth;
          photoBase64 = data['photoBase64'] ?? "";
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('inventory').orderBy('percentage').limit(1).snapshots(),
          builder: (context, stockSnapshot) {
            String lowestStockName = "Towels";
            int lowestPercentage = 15;
            String lowestStockPhoto = "";

            if (stockSnapshot.hasData && stockSnapshot.data!.docs.isNotEmpty) {
              var lowStockDoc = stockSnapshot.data!.docs.first.data() as Map<String, dynamic>;
              lowestStockName = lowStockDoc['name'] ?? "Stock";
              lowestPercentage = lowStockDoc['percentage'] ?? 0;
              lowestStockPhoto = lowStockDoc['photoBase64'] ?? "";
            }

            return Row(
              children: [
                Expanded(
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2B49C),
                      borderRadius: BorderRadius.circular(25),
                      image: photoBase64.isNotEmpty
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(photoBase64)),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.3), BlendMode.darken),
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Monthly Best Staff",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(month,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0)),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)
                      ],
                      image: lowestStockPhoto.isNotEmpty
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(lowestStockPhoto)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 4),
                                Text("Alerts Stock",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text('$lowestPercentage%',
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: lowestPercentage <= 20
                                    ? Colors.red
                                    : Colors.black87,
                                height: 1.0)),
                        Text(lowestStockName,
                            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showRoleGuide(String roleName) {
    String title = "";
    List<String> tasks = [];
    IconData icon = Icons.person;

    switch (roleName) {
      case 'Manager':
        title = "Manager's Role";
        icon = Icons.admin_panel_settings_outlined;
        tasks = [
          "• Authorize and manage bulk stock purchase orders.",
          "• Monitor real-time hotel budget and financial health.",
          "• Analyze monthly inventory consumption and reports.",
          "• Oversee supplier relations and payment gateways.",
          "• Manage team access levels and system configurations."
        ];
        break;
      case 'Supervisor':
        title = "Supervisor's Role";
        icon = Icons.assignment_ind_outlined;
        tasks = [
          "• Monitor live stock levels and low inventory alerts.",
          "• Create and track purchase requests for approval.",
          "• Assign daily tasks and room audits to housekeeping.",
          "• Manage internal stock distribution and tracking.",
          "• Generate and export PDF reports for inventory audits."
        ];
        break;
      case 'Housekeeping':
        title = "Housekeeping Role";
        icon = Icons.cleaning_services_outlined;
        tasks = [
          "• Perform room inventory checks and report usage.",
          "• Request items for daily cleaning and replenishment.",
          "• Report damaged or missing inventory immediately.",
          "• Update task progress and room cleaning status.",
          "• Use QR scanner for fast inventory updates."
        ];
        break;
      case 'Supplier':
        title = "Supplier's Role";
        icon = Icons.local_shipping_outlined;
        tasks = [
          "• Maintain product catalog and unit price updates.",
          "• Receive and process incoming purchase orders.",
          "• Update delivery status and estimated arrival times.",
          "• Upload proof of delivery for completed shipments.",
          "• Access transaction history and payment records."
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFC98A6B).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: const Color(0xFFC98A6B), size: 30),
                ),
                const SizedBox(width: 15),
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF302B2C))),
              ],
            ),
            const SizedBox(height: 25),
            const Text("Core Responsibilities:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 15),
            ...tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(task, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
            )).toList(),
            const Divider(height: 40),
            // Credit Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFC98A6B).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 20, color: Color(0xFFC98A6B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("System Developed by Akmal Shukri", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF302B2C))),
                        const Text("For maintenance: 011 33031316", 
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF302B2C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Got it, Thanks!", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Role Responsibilities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildOrgButton("Manager", Icons.admin_panel_settings_outlined, () => _showRoleGuide('Manager')),
            const SizedBox(width: 8),
            _buildOrgButton("Supervisor", Icons.assignment_ind_outlined, () => _showRoleGuide('Supervisor')),
            const SizedBox(width: 8),
            _buildOrgButton("Housekeeping", Icons.cleaning_services_outlined, () => _showRoleGuide('Housekeeping')),
            const SizedBox(width: 8),
            _buildOrgButton("Supplier", Icons.local_shipping_outlined, () => _showRoleGuide('Supplier')),
          ],
        ),
      ],
    );
  }

  Widget _buildOrgButton(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC98A6B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFC98A6B), size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF302B2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDDE5ED),
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () async {
          final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
          if (scannedCode != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $scannedCode'), backgroundColor: Colors.amber.shade900));
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text("Scan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF302B2C), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            )
          ],
        ),
      ),
    );
  }
}
