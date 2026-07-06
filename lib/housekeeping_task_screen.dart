import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io' show File;
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_settings_screen.dart';
import 'scanner_screen.dart';
import 'room_checklist_screen.dart';
import 'housekeeping_activity_screen.dart';
import 'housekeeping_stock_distribution.dart';
import 'login_screen.dart';

class HousekeepingTaskScreen extends StatefulWidget {
  final Map<String, dynamic> housekeepingProfile;
  const HousekeepingTaskScreen({super.key, required this.housekeepingProfile});

  @override
  State<HousekeepingTaskScreen> createState() => _HousekeepingTaskScreenState();
}

class _HousekeepingTaskScreenState extends State<HousekeepingTaskScreen> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  String filterStatus = "All"; // All, Completed, Pending
  File? _profileImage;
  String hotelLogoUrl = ""; // Holds the Base64 data for the Hotel Logo

  // Real-time task stats
  int roomsCleanedToday = 0;
  int pendingRoomsCount = 0;
  int damagedReportedCount = 2; // Mock for now

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
    _listenToHotelLogoData();
    _fetchTaskStats();
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

  void _fetchTaskStats() {
    // 1. Listen to rooms cleaned by THIS specific staff TODAY
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    FirebaseFirestore.instance
        .collectionGroup('rooms')
        .where('completedByEmail', isEqualTo: widget.housekeepingProfile['email'])
        .where('status', isEqualTo: 'Completed')
        .where('timestamp', isGreaterThanOrEqualTo: startOfToday)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          roomsCleanedToday = snapshot.docs.length;
        });
      }
    });

    // 2. Listen to all completed rooms to calculate Pending
    FirebaseFirestore.instance
        .collectionGroup('rooms')
        .where('status', isEqualTo: 'Completed')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          int totalCompleted = snapshot.docs.length;
          pendingRoomsCount = 100 - totalCompleted;
        });
      }
    });

    // 3. Listen to Damaged Reports from the last 7 days
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
    FirebaseFirestore.instance
        .collection('damaged_reports')
        .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          damagedReportedCount = snapshot.docs.length;
        });
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
                        _buildSearchField(),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("My Tasks",
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _fetchTaskStats();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Refreshing tasks..."),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: Color(0xFFC98A6B),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5)
                                  ],
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.refresh,
                                        size: 16, color: Color(0xFFC98A6B)),
                                    SizedBox(width: 4),
                                    Text("Reload",
                                        style: TextStyle(
                                            color: Color(0xFFC98A6B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTaskStats(),
                        const SizedBox(height: 25),
                        _buildAssignedToMeSection(),
                        const SizedBox(height: 25),
                        _buildLevelFilterSection(),
                        const SizedBox(height: 15),
                        _buildLevelsList(),
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

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
        decoration: const InputDecoration(
          hintText: "Search Hotel Level or Room",
          hintStyle: TextStyle(color: Colors.black26),
          prefixIcon: Icon(Icons.search, color: Color(0xFFC98A6B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildTaskStats() {
    return Column(
      children: [
        _buildStatCard("Room Cleaned today", roomsCleanedToday.toString(), Icons.check_circle_outline),
        const SizedBox(height: 12),
        _buildStatCard("Pending Room", pendingRoomsCount.toString(), Icons.hourglass_empty),
        const SizedBox(height: 12),
        _buildStatCard("Damaged Reported", damagedReportedCount.toString(), Icons.report_problem_outlined),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFC98A6B),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFFC98A6B).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF302B2C)),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedToMeSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('rooms')
          .where('assignedToEmail', isEqualTo: widget.housekeepingProfile['email'])
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        var assignedRooms = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notification_important, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  "Assigned to Me",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: assignedRooms.length,
                itemBuilder: (context, index) {
                  var room = assignedRooms[index].data() as Map<String, dynamic>;
                  int roomNum = room['roomNumber'];
                  int level = room['level'];

                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Room $roomNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Level $level", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomChecklistScreen(
                                  roomNumber: roomNum,
                                  level: level,
                                  housekeepingProfile: widget.housekeepingProfile,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("Start Now", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelFilterSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Hotel Level",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF302B2C)),
            ),
            Row(
              children: [
                _buildFilterChip("Completed", Icons.check_circle, Colors.green, "Completed"),
                const SizedBox(width: 8),
                _buildFilterChip("Not Completed", Icons.cancel, Colors.red, "Pending"),
              ],
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => filterStatus = "All"),
            child: const Text("See All", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, String status) {
    bool isSelected = filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => filterStatus = isSelected ? "All" : status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsList() {
    // Generate levels 10 down to 1
    List<int> levels = List.generate(10, (index) => 10 - index);
    
    // Simple filter
    if (searchQuery.isNotEmpty) {
      levels = levels.where((l) => "Level $l".toLowerCase().contains(searchQuery)).toList();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        int levelNum = levels[index];
        return _buildLevelTile(levelNum);
      },
    );
  }

  Widget _buildLevelTile(int levelNum) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('housekeeping_tasks')
          .doc('level_$levelNum')
          .collection('rooms')
          .snapshots(),
      builder: (context, snapshot) {
        int completedCount = 0;
        String lastCompletedBy = "None";
        String assignedStaff = "Not Assigned"; // Default if not assigned
        
        if (snapshot.hasData) {
          var docs = snapshot.data!.docs;
          completedCount = docs.where((d) => d['status'] == 'Completed').length;
          
          if (completedCount > 0) {
            // Get the name of someone who completed a room here
            lastCompletedBy = docs.firstWhere((d) => d['status'] == 'Completed')['completedBy'] ?? "Staff";
          }

          // Check if any pending room has an assignment (future proofing)
          var assignedDoc = docs.where((d) => (d.data() as Map<String, dynamic>).containsKey('assignedToName')).toList();
          if (assignedDoc.isNotEmpty) {
            assignedStaff = assignedDoc.first['assignedToName'] ?? "Not Assigned";
          }
        }

        bool isFullyCompleted = completedCount == 10;
        
        // Apply status filter
        if (filterStatus == "Completed" && !isFullyCompleted) return const SizedBox.shrink();
        if (filterStatus == "Pending" && isFullyCompleted) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFullyCompleted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFullyCompleted ? Icons.check_circle : Icons.cancel,
                color: isFullyCompleted ? Colors.green : Colors.red,
                size: 28,
              ),
            ),
            title: Text(
              "Level $levelNum",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  isFullyCompleted ? "Completed by" : "Assigned to",
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFullyCompleted ? lastCompletedBy : assignedStaff,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: assignedStaff == "Not Assigned" && !isFullyCompleted ? Colors.orange.shade800 : Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Status", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      "$completedCount/10",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black45),
              ],
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE6D7).withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  children: List.generate(10, (roomIdx) {
                    int roomNum = (levelNum * 100) + (roomIdx + 1);
                    return _buildRoomItem(levelNum, roomNum);
                  }),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomItem(int level, int roomNumber) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('housekeeping_tasks')
          .doc("level_$level")
          .collection('rooms')
          .doc("room_$roomNumber")
          .snapshots(),
      builder: (context, snapshot) {
        bool isDone = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isDone = snapshot.data!['status'] == 'Completed';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : Colors.black12),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? Colors.green : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                "Room $roomNumber",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDone ? Colors.black87 : Colors.black54,
                ),
              ),
              const Spacer(),
              // Inspect Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomChecklistScreen(
                        roomNumber: roomNumber,
                        level: level,
                        housekeepingProfile: widget.housekeepingProfile,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDDE5ED),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Inspect", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              // Scan Button
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                  if (result != null) {
                    // Professional Validation: Check if scanned QR matches THIS specific room
                    final String expectedCode = "ROOM_${level}_$roomNumber";
                    
                    if (result == expectedCode) {
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomChecklistScreen(
                              roomNumber: roomNumber,
                              level: level,
                              housekeepingProfile: widget.housekeepingProfile,
                            ),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text("Wrong Room!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            content: Text("Error: You scanned the wrong room. This QR is for a different area. Please scan the QR code for Room $roomNumber."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDone ? Colors.grey.shade100 : const Color(0xFFDDE5ED),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Text("Scan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                label: const Icon(Icons.qr_code_scanner, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markRoomAsCleaned(int roomNumber, int level) async {
    await FirebaseFirestore.instance
        .collection('housekeeping_tasks')
        .doc("level_$level")
        .collection('rooms')
        .doc("room_$roomNumber")
        .set({
      'roomNumber': roomNumber,
      'level': level,
      'status': 'Completed',
      'completedBy': widget.housekeepingProfile['name'],
      'completedByEmail': widget.housekeepingProfile['email'],
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Room $roomNumber marked as cleaned!")),
      );
    }
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
              _buildDrawerItem(Icons.assignment_outlined, "Task", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(
                Icons.inventory_2_outlined,
                "Stock Distribution",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HousekeepingStockDistribution(housekeepingProfile: widget.housekeepingProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.history,
                "My Activity",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HousekeepingActivityScreen(housekeepingProfile: widget.housekeepingProfile)),
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
