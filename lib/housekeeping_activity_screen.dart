import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io' show File;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'profile_settings_screen.dart';
import 'housekeeping_task_screen.dart';
import 'housekeeping_stock_distribution.dart';
import 'login_screen.dart';

class HousekeepingActivityScreen extends StatefulWidget {
  final Map<String, dynamic> housekeepingProfile;
  const HousekeepingActivityScreen({super.key, required this.housekeepingProfile});

  @override
  State<HousekeepingActivityScreen> createState() => _HousekeepingActivityScreenState();
}

class _HousekeepingActivityScreenState extends State<HousekeepingActivityScreen> {
  bool isDrawerOpen = false;
  File? _profileImage;
  String hotelLogoUrl = "";
  
  String startTime = "--:--";
  String endTime = "--:--";

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
    _listenToHotelLogoData();
    _fetchDailyWorkTimes();
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

    final String uniqueId = widget.housekeepingProfile['username'] ?? widget.housekeepingProfile['email'] ?? 'default_user';
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

  void _fetchDailyWorkTimes() {
    DateTime now = DateTime.now();
    String dateKey = "${now.year}-${now.month}-${now.day}";
    String docId = "${widget.housekeepingProfile['email']}_$dateKey";

    FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        Timestamp? firstStart = data['startTime'] as Timestamp?;
        Timestamp? lastEnd = data['endTime'] as Timestamp?;

        if (mounted) {
          setState(() {
            startTime = firstStart != null ? DateFormat('hh:mm a').format(firstStart.toDate()) : "--:--";
            endTime = lastEnd != null ? DateFormat('hh:mm a').format(lastEnd.toDate()) : "--:--";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            startTime = "--:--";
            endTime = "--:--";
          });
        }
      }
    });
  }

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.housekeepingProfile['email'];
    if (email.isNotEmpty) {
      DateTime now = DateTime.now();
      String dateKey = "${now.year}-${now.month}-${now.day}";
      String docId = "${email}_$dateKey";
      DocumentReference attendanceRef = FirebaseFirestore.instance.collection('attendance').doc(docId);

      final attendanceSnap = await attendanceRef.get();
      
      if (isAvailable) {
        if (!attendanceSnap.exists) {
          await attendanceRef.set({
            'email': email,
            'date': dateKey,
            'startTime': FieldValue.serverTimestamp(),
            'currentSessionStart': FieldValue.serverTimestamp(),
            'totalSeconds': 0,
            'endTime': null,
          });
        } else {
          var data = attendanceSnap.data() as Map<String, dynamic>;
          if (data['currentSessionStart'] == null) {
            await attendanceRef.update({
              'currentSessionStart': FieldValue.serverTimestamp(),
            });
          }
        }
      } else {
        if (attendanceSnap.exists) {
          var data = attendanceSnap.data() as Map<String, dynamic>;
          Timestamp? sessionStartTs = data['currentSessionStart'] as Timestamp?;
          int totalSeconds = data['totalSeconds'] ?? 0;

          if (sessionStartTs != null) {
            int sessionDuration = now.difference(sessionStartTs.toDate()).inSeconds;
            totalSeconds += sessionDuration;
          }

          await attendanceRef.update({
            'endTime': FieldValue.serverTimestamp(),
            'currentSessionStart': null,
            'totalSeconds': totalSeconds,
          });
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text("My Activity", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        _buildTimeSummaryCard(),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Rooms Completed (This Month)"),
                        _buildMonthlyRoomsList(startOfMonth),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Damage Reports (This Month)"),
                        _buildMonthlyDamageReports(startOfMonth),
                        const SizedBox(height: 30),
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
      stream: FirebaseFirestore.instance.collection('users').doc(widget.housekeepingProfile['email']).snapshots(),
      builder: (context, snapshot) {
        String photoBase64 = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          photoBase64 = (snapshot.data!.data() as Map<String, dynamic>)['photoBase64'] ?? "";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.list, size: 30),
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
                    MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.housekeepingProfile)),
                  );
                  _loadSavedProfileImage();
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: photoBase64.isNotEmpty
                          ? MemoryImage(base64Decode(photoBase64))
                          : (!kIsWeb && _profileImage != null ? FileImage(_profileImage!) : null),
                      child: (photoBase64.isEmpty && (kIsWeb || _profileImage == null)) ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const Text("Housekeeping Staff", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC98A6B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeInfo("Start Time", startTime, Icons.play_circle_outline),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildTimeInfo("End Time", endTime, Icons.stop_circle_outlined),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildMonthlyRoomsList(DateTime startOfMonth) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('rooms')
          .where('completedByEmail', isEqualTo: widget.housekeepingProfile['email'])
          .where('status', isEqualTo: 'Completed')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No rooms completed this month.");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            DateTime date = (doc['timestamp'] as Timestamp).toDate();
            return _buildActivityTile(
              "Room ${doc['roomNumber']}",
              "Level ${doc['level']}",
              DateFormat('dd MMM, hh:mm a').format(date),
              Icons.check_circle,
              Colors.green,
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyDamageReports(DateTime startOfMonth) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('damaged_reports')
          .where('staffEmail', isEqualTo: widget.housekeepingProfile['email'])
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No damage reported this month.");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            DateTime date = (doc['timestamp'] as Timestamp).toDate();
            return _buildActivityTile(
              doc['category'] ?? "Damage Report",
              "Room ${doc['roomNumber']}",
              DateFormat('dd MMM, hh:mm a').format(date),
              Icons.report_problem,
              Colors.redAccent,
            );
          },
        );
      },
    );
  }

  Widget _buildActivityTile(String title, String subtitle, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
              _buildDrawerItem(Icons.assignment_outlined, "Task", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HousekeepingTaskScreen(housekeepingProfile: widget.housekeepingProfile)),
                );
              }),
              _buildDrawerItem(
                Icons.inventory_2_outlined,
                "Stock Distribution",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HousekeepingStockDistribution(housekeepingProfile: widget.housekeepingProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(Icons.history, "My Activity", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.settings,
                "Settings",
                onTap: () async {
                  setState(() => isDrawerOpen = false);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.housekeepingProfile)),
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
