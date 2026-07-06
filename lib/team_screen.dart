import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_settings_screen.dart';
import 'housekeeping_performance_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'supervisor_room_assignment.dart';
import 'inventory_store_scan_page.dart';
import 'manager_financial_screen.dart';
import 'login_screen.dart';
import 'manager_purchases_screen.dart';
import 'manager_stock_tracking.dart';

class TeamScreen extends StatefulWidget {
  final Map<String, dynamic> currentUserProfile;
  const TeamScreen({super.key, required this.currentUserProfile});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String hotelLogoUrl = ""; // Holds the Base64 data for the Hotel Logo

  @override
  void initState() {
    super.initState();
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

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.currentUserProfile['email'];
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
    bool canEdit = widget.currentUserProfile['role'] == 'Manager' || widget.currentUserProfile['role'] == 'Supervisor';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. Header (Logo, Profile Pic)
                _buildHeader(),
                
                // 2. Staff Team Title & Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Staff Team",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: "Search Staff",
                            prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Staff List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Error loading team"));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      var allUsers = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                      var filteredUsers = allUsers.where((u) {
                        String name = (u['name'] ?? "").toLowerCase();
                        String sid = (u['staffId'] ?? "").toLowerCase();
                        return name.contains(searchQuery) || sid.contains(searchQuery);
                      }).toList();

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          _buildRoleSection("Housekeeping Staff", filteredUsers.where((u) => u['role'] == 'Housekeeping').toList(), canEdit),
                          _buildRoleSection("Supervisor Staff", filteredUsers.where((u) => u['role'] == 'Supervisor').toList(), canEdit),
                          _buildRoleSection("Manager Staff", filteredUsers.where((u) => u['role'] == 'Manager').toList(), canEdit),
                        ],
                      );
                    },
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

  void _showResetPasswordDialog(Map<String, dynamic> staff) {
    final TextEditingController newPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: Colors.redAccent),
              const SizedBox(width: 10),
              Flexible(child: Text("Reset Password for ${staff['name']}", style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter a new temporary password for this staff member.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: "New Password",
                  hintText: "Enter at least 6 characters",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.password),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isUpdating ? null : () async {
                String newPass = newPasswordController.text.trim();
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters.")));
                  return;
                }

                setDialogState(() => isUpdating = true);
                try {
                  await FirebaseFirestore.instance.collection('users').doc(staff['email']).update({
                    'password': newPass,
                    'forcePasswordChange': true, // 👈 FLAG: Forces user to change this on login
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Password reset successfully for ${staff['name']}!"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isUpdating = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
              },
              child: isUpdating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Reset Now", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.currentUserProfile['email']).snapshots(),
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
                icon: const Icon(Icons.list, color: Colors.black87, size: 30),
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
              Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: photoBase64.isNotEmpty
                        ? MemoryImage(base64Decode(photoBase64))
                        : null,
                    child: photoBase64.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                  ),
                  Text(widget.currentUserProfile['role'] ?? 'Staff', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRoleSection(String title, List<Map<String, dynamic>> users, bool canEdit) {
    if (users.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
          decoration: const BoxDecoration(
            color: Color(0xFFD2B49C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: users.map((u) => _buildStaffTile(u, canEdit)).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff, bool canEdit) {
    // 💡 LIVE STATUS CHECK (Option B):
    // Check if status is Available AND lastSeen was within the last 3 minutes.
    bool isActuallyAvailable = false;
    if (staff['status'] == 'Available') {
      Timestamp? lastSeenTs = staff['lastSeen'] as Timestamp?;
      if (lastSeenTs != null) {
        DateTime lastSeenDate = lastSeenTs.toDate();
        DateTime threeMinutesAgo = DateTime.now().subtract(const Duration(minutes: 3));
        if (lastSeenDate.isAfter(threeMinutesAgo)) {
          isActuallyAvailable = true;
        }
      }
    }

    String photoBase64 = staff['photoBase64'] ?? "";
    String email = staff['email'] ?? "";
    DateTime now = DateTime.now();
    String dateKey = "${now.year}-${now.month}-${now.day}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: photoBase64.isNotEmpty
                ? MemoryImage(base64Decode(photoBase64))
                : null,
            child: photoBase64.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(staff['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (staff['isStarred'] == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.stars, color: Colors.amber, size: 16),
                      ),
                  ],
                ),
                Text(staff['staffId'] ?? "No ID", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                
                // 🕒 Active Time Display for Housekeeping
                if (staff['role'] == 'Housekeeping')
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('attendance').doc("${email}_$dateKey").snapshots(),
                    builder: (context, attendanceSnap) {
                      if (!attendanceSnap.hasData || !attendanceSnap.data!.exists) {
                        return const Text("Not started today", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic));
                      }
                      
                      var data = attendanceSnap.data!.data() as Map<String, dynamic>;
                      int accumulatedSeconds = data['totalSeconds'] ?? 0;
                      Timestamp? sessionStartTs = data['currentSessionStart'] as Timestamp?;
                      
                      int displaySeconds = accumulatedSeconds;
                      if (isActuallyAvailable && sessionStartTs != null) {
                        displaySeconds += DateTime.now().difference(sessionStartTs.toDate()).inSeconds;
                      }

                      int hours = displaySeconds ~/ 3600;
                      int minutes = (displaySeconds % 3600) ~/ 60;
                      
                      String activeStr = "${hours}h ${minutes}m active";
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFC98A6B)),
                            const SizedBox(width: 4),
                            Text(activeStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC98A6B))),
                          ],
                        ),
                      );
                    },
                  ),
                

                // 🛠️ Permission Check: Managers can 'Edit', Supervisors can 'View'
                if (widget.currentUserProfile['role'] == 'Manager' || widget.currentUserProfile['role'] == 'Supervisor')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileSettingsScreen(
                                  userProfile: staff,
                                  isReadOnly: widget.currentUserProfile['role'] == 'Supervisor',
                                  showBackButton: true,
                                ),
                              ),
                            );
                            if (updated != null) setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              widget.currentUserProfile['role'] == 'Manager' ? "Edit Details" : "View Details",
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showResetPasswordDialog(staff),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              "Reset Password",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isActuallyAvailable ? "Available" : "Not Available",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isActuallyAvailable ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          if (staff['role'] == 'Housekeeping')
            Column(
              children: [
                const Text("Performance",
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HousekeepingPerformanceScreen(
                            staffProfile: staff),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC98A6B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.analytics_outlined,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text("View",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
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
              if (widget.currentUserProfile['role'] == 'Manager') ...[
                _buildDrawerItem(Icons.shopping_bag, "Purchases", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerPurchasesScreen(managerProfile: widget.currentUserProfile)));
                }),
                _buildDrawerItem(Icons.analytics, "Financial", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerFinancialScreen(managerProfile: widget.currentUserProfile)));
                }),
                _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerStockTracking(managerProfile: widget.currentUserProfile)));
                }),
              ]
 else if (widget.currentUserProfile['role'] == 'Supervisor') ...[
                _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorInventoryScreen(supervisorProfile: widget.currentUserProfile),
                    ),
                  );
                }),
                _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.currentUserProfile),
                    ),
                  );
                }),
                _buildDrawerItem(
                  Icons.assignment_ind_outlined,
                  "Room Assignment",
                  onTap: () {
                    setState(() => isDrawerOpen = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupervisorRoomAssignment(supervisorProfile: widget.currentUserProfile),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  Icons.settings_remote,
                  "Inventory Store Station",
                  onTap: () {
                    setState(() => isDrawerOpen = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InventoryStoreScanPage(supervisorProfile: widget.currentUserProfile),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorStockTracking(supervisorProfile: widget.currentUserProfile),
                    ),
                  );
                }),
              ],
              _buildDrawerItem(Icons.people, "Team", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.settings,
                "Settings",
                onTap: () async {
                  setState(() => isDrawerOpen = false);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(userProfile: widget.currentUserProfile),
                    ),
                  );
                  setState(() {});
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
