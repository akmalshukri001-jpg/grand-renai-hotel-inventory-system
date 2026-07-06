import 'package:flutter/material.dart';
import 'dart:convert'; // 👈 CRITICAL: Needed for Base64 coding transformations
import 'dart:ui';
import 'dart:async'; // 👈 Added Timer
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gamification_service.dart';
import 'profile_settings_screen.dart';
import 'scanner_screen.dart';
import 'team_screen.dart';
import 'manager_purchases_screen.dart';
import 'manager_financial_screen.dart';
import 'manager_stock_tracking.dart';
import 'inventory_store_scan_page.dart';
import 'login_screen.dart';


class ManagerDashboard extends StatefulWidget {
  final Map<String, dynamic> managerProfile;
  const ManagerDashboard({super.key, required this.managerProfile});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  // 🌍 Live state variables synchronized with your database structures
  String eventTitle = "Loading Event...";
  String eventImageUrl = ""; // Holds the Base64 data from Firestore
  String hotelLogoUrl = ""; // Holds the Base64 data for the Hotel Logo
  bool isDrawerOpen = false;
  File? _profileImage;
  Timer? _heartbeatTimer; // 👈 Added Timer variable
  final ImagePicker _picker = ImagePicker();

  // 📝 Text Controller for modifying the live event headline
  final TextEditingController _eventTextController = TextEditingController();

  // Stats variables (Holding for later update)
  String bestStaffName = "Junoh Hassan";
  String bestStaffMonth = "Jan 2026";
  int towelStockPercentage = 15;
  double hotelBudget = 30000.0;

  // 🖼️ Internal variables for managing the dynamic banner upload loop
  File? _pickedEventImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage(); // Automatically loads the profile picture unique to this user ID
    _listenToLiveEventData();  // Starts the real-time cloud sync connection immediately
    _listenToHotelLogoData();  // Starts listening for Hotel Logo updates
    _listenToBudgetData();     // Starts budget sync
    _updateUserStatus(true);   // Set user as Available when dashboard opens
    _startHeartbeat();         // 👈 Start heartbeat
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updateUserStatus(true);
    });
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

  void _listenToBudgetData() {
    FirebaseFirestore.instance
        .collection('financial_metadata')
        .doc('budget')
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null) {
        if (mounted) {
          setState(() {
            hotelBudget = (snap.data()!['balance'] ?? 30000.0).toDouble();
          });
        }
      }
    });
  }


  @override
  void didUpdateWidget(covariant ManagerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.managerProfile['username'] != widget.managerProfile['username']) {
      _loadSavedProfileImage();
      _listenToLiveEventData(); // Re-sync if the account shifts live
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel(); // 👈 Stop timer
    _eventTextController.dispose(); // Clean memory paths on widget destruction
    super.dispose();
  }

  // 📡 CLOUD STREAM: Listens to updates from your Firestore current document automatically
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

  // 📡 CLOUD STREAM: Listens to updates for the Hotel Logo
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

  // 📸 AUX FUNCTION: Handles picking a local photo file for the dynamic event container
  Future<void> _pickEventImage(StateSetter modalSetState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedEventImage = File(pickedFile.path); // Still need for internal local preview on mobile
          eventImageUrl = base64Encode(bytes); // Update the Base64 state
        });
        modalSetState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking banner image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📥 ARCHIVE METHOD: Pushes modifications out to the public, then registers an history trace receipt
  Future<void> _updateEventInFirebase(String newTitle) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final String staffId = widget.managerProfile['username'] ?? widget.managerProfile['email'] ?? 'MGR-UNKNOWN';
    final String staffName = widget.managerProfile['username'] ?? 'Manager Account';
    final Timestamp rightNow = Timestamp.now();

    setState(() => _isUploading = true);
    String finalImageString = eventImageUrl;

    try {
      if (_pickedEventImage != null) {
        // 🔄 Convert the chosen image file bytes into a Base64 Text String
        final bytes = await _pickedEventImage!.readAsBytes();
        finalImageString = base64Encode(bytes);
      }

      // 1. Sync live configuration to metadata collection (Real-time update)
      await firestore.collection('events_metadata').doc('current').set({
        'title': newTitle,
        'imageUrl': finalImageString, // Saves raw Base64 data directly here
        'updatedBy': staffId,
        'updatedByName': staffName,
        'updatedAt': rightNow,
      }, SetOptions(merge: true));

      // 2. Log trace receipt down inside the history ledger
      await firestore.collection('event_history').add({
        'title': newTitle,
        'imageUrl': finalImageString,
        'changedBy': staffId,
        'changedByName': staffName,
        'timestamp': rightNow,
        'action': 'UPDATED_EVENT_BANNER'
      });

      setState(() {
        eventTitle = newTitle;
        eventImageUrl = finalImageString;
        _pickedEventImage = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard banner updated cleanly from gallery!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database Save Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 📥 METHOD: Updates the Hotel Logo in Firestore
  Future<void> _updateHotelLogoInFirebase() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      try {
        final bytes = await pickedFile.readAsBytes();
        final String base64Image = base64Encode(bytes);

        await FirebaseFirestore.instance.collection('hotel_metadata').doc('logo').set({
          'imageUrl': base64Image,
          'updatedBy': widget.managerProfile['email'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotel Logo updated successfully!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating Hotel Logo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 📥 METHOD: Removes the Hotel Logo from Firestore
  Future<void> _removeHotelLogoFromFirebase() async {
    try {
      await FirebaseFirestore.instance.collection('hotel_metadata').doc('logo').update({
        'imageUrl': '',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotel Logo removed.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing Hotel Logo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 💾 MEMORY FUNCTION: Retrieve the saved image path for this specific manager account
  Future<void> _loadSavedProfileImage() async {
    if (kIsWeb) return; // Web cannot access local File paths

    final String uniqueId = widget.managerProfile['username'] ?? widget.managerProfile['email'] ?? 'default_manager';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString('manager_profile_path_$uniqueId');

    if (imagePath != null && imagePath.isNotEmpty) {
      File savedFile = File(imagePath);
      if (await savedFile.exists()) {
        setState(() {
          _profileImage = savedFile;
        });
        return; // Exit once found
      }
    }
    
    // If no image found or file doesn't exist, reset to null to show default
    setState(() {
      _profileImage = null;
    });
  }

  // 📸 FUNCTION: Opens phone gallery to pick a picture and saves it to a unique user slot + Cloud
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final String base64Image = base64Encode(bytes);
        final String email = widget.managerProfile['email'];

        // 1. Update Cloud immediately
        await FirebaseFirestore.instance.collection('users').doc(email).update({
          'photoBase64': base64Image,
        });
        
        // 2. Update local state (Mobile only for File object)
        if (!kIsWeb) {
          setState(() {
            _profileImage = File(pickedFile.path);
          });
          
          final String uniqueId = widget.managerProfile['username'] ?? email;
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('manager_profile_path_$uniqueId', pickedFile.path);
        } else {
          // On Web, we just rely on the Firestore Stream which will update the CircleAvatar
          setState(() {}); 
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture synced to Cloud!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 🗑️ FUNCTION: Removes photo back to dynamic placeholder and clears Cloud
  Future<void> _clearProfileImage() async {
    final String email = widget.managerProfile['email'];
    final String uniqueId = widget.managerProfile['username'] ?? email;
    
    await FirebaseFirestore.instance.collection('users').doc(email).update({
      'photoBase64': "",
    });

    setState(() {
      _profileImage = null;
    });

    if (!kIsWeb) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('manager_profile_path_$uniqueId');
    }
  }

  // ⚙️ BOTTOM SHEET MODAL PROMPT FOR SUPERVISORS & MANAGERS ONLY
  void _showEventEditBottomSheet() {
    _eventTextController.text = eventTitle;
    _pickedEventImage = null; // Clear historical caching frames on open entry

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Update Latest Event Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 15),

                  // 🖼️ NATIVE GALLERY PICKER TARGET INTERACTIVE BOX
                  GestureDetector(
                    onTap: () async {
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 400,   // 💡 Compressed sizing bounds keeps data light
                        maxHeight: 250,  // and well under Firestore's 16MB doc cap
                        imageQuality: 65,
                      );

                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setModalState(() {
                          if (!kIsWeb) _pickedEventImage = File(pickedFile.path);
                          eventImageUrl = base64Encode(bytes);
                        });
                      }
                    },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        image: (eventImageUrl.isNotEmpty)
                            ? DecorationImage(
                            image: MemoryImage(base64Decode(eventImageUrl)), // 👈 Decodes data instantly to render layout frame
                            fit: BoxFit.cover)
                            : (!kIsWeb && _pickedEventImage != null
                              ? DecorationImage(image: FileImage(_pickedEventImage!), fit: BoxFit.cover)
                              : null),
                      ),
                      child: _pickedEventImage == null && eventImageUrl.isEmpty
                          ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                            SizedBox(height: 4),
                            Text("Tap to pick image from Gallery", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                          : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _eventTextController,
                    decoration: InputDecoration(
                      labelText: "Event Title / Description",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(modalContext),
                          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isUploading
                              ? null
                              : () async {
                            final String updatedTitle = _eventTextController.text.trim();
                            if (updatedTitle.isNotEmpty) {
                              Navigator.pop(modalContext);
                              await _updateEventInFirebase(updatedTitle);
                            }
                          },
                          child: _isUploading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background like in the image
      body: Stack(
        children: [
          // MAIN CONTENT AREA
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // 1. Header Row (Menu, Logo, Profile)
                    _buildHeaderRow(),
                    const SizedBox(height: 20),
                    // 2. Hotel Inventory Title Banner
                    _buildTitleBanner(),
                    const SizedBox(height: 25),
                    _buildLiveEventSection(),
                    const SizedBox(height: 25),
                    // 4. Twin Stats Row (Staff & Stock)
                    _buildTwinStatsRow(),
                    const SizedBox(height: 25),
                    _buildPerformanceSummaryCard(),
                    const SizedBox(height: 25),
                    // 5. Organization Chart
                    _buildOrganizationChartSection(),
                    const SizedBox(height: 30),
                    // 6. Scan Button
                    _buildScanButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // CUSTOM DRAWER OVERLAY
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
      ),
    );
  }

  // 📡 REAL-TIME EVENT SECTION: Combined logic and visuals
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

        final bool canEdit = (widget.managerProfile['role'] == 'Manager' || widget.managerProfile['role'] == 'Supervisor');

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
                  if (canEdit)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                        onPressed: _showEventEditBottomSheet,
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
                Icons.shopping_bag,
                "Purchases",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerPurchasesScreen(managerProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.analytics,
                "Financial",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
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
                  Navigator.push(
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamScreen(currentUserProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.settings_remote,
                "Inventory Store Station",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryStoreScanPage(supervisorProfile: widget.managerProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                Icons.settings,
                "Settings",
                onTap: () async {
                  setState(() => isDrawerOpen = false);
                  final updatedProfile = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile),
                    ),
                  );
                  if (updatedProfile != null) {
                    setState(() {
                      // Force refresh the profile image and local data
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
      stream: FirebaseFirestore.instance.collection('users').doc(widget.managerProfile['email']).snapshots(),
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
            // HOTEL LOGO CIRCLE (Clickable for Manager to change)
            GestureDetector(
              onTap: widget.managerProfile['role'] == 'Manager' ? () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Hotel Logo Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library, color: Colors.blue),
                          title: const Text('Change Hotel Logo'),
                          onTap: () {
                            Navigator.pop(context);
                            _updateHotelLogoInFirebase();
                          },
                        ),
                        if (hotelLogoUrl.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.pop(context);
                              _removeHotelLogoFromFirebase();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              } : null,
              child: Container(
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
            ),
            GestureDetector(
              onTap: () async {
                final updatedProfile = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile),
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
                  const Text("Manager", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        );
      }
    );
  }

  void _manageProfilePicture() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Profile Picture Options',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose From Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            if (_profileImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _clearProfileImage();
                },
              ),
          ],
        ),
      ),
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

  Widget _buildLatestEventsSection() {
    final String userRole = widget.managerProfile['role'] ?? 'Staff';
    final bool canEdit = (userRole == 'Manager' || userRole == 'Supervisor');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Latest Events", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.amber.shade800,
            image: DecorationImage(
              image: eventImageUrl.isNotEmpty
                  ? MemoryImage(base64Decode(eventImageUrl))
                  : const AssetImage('assets/images/event_placeholder.png') as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 12,
                left: 16,
                child: Text(
                  eventTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
              if (canEdit)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.white, size: 28),
                    onPressed: () => _showEventEditBottomSheet(),
                  ),
                )
            ],
          ),
        ),
      ],
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
                    child: Stack(
                      children: [
                        Column(
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
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(),
                        )
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
                        Text(
                          '$lowestPercentage%',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: lowestPercentage <= 30
                                  ? Colors.red
                                  : Colors.black87,
                              height: 1.0),
                        ),
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

  void _editBestStaffPrompt() {
    TextEditingController nameCtrl = TextEditingController(text: bestStaffName);
    TextEditingController monthCtrl = TextEditingController(text: bestStaffMonth);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nominate Best Staff"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: monthCtrl, decoration: const InputDecoration(labelText: "Month/Year Horizon")),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Staff Name")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                bestStaffName = nameCtrl.text.trim();
                bestStaffMonth = monthCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF302B2C),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Staff Performance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Real-time housekeeping metrics", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showLeaderboard,
                icon: const Icon(Icons.leaderboard, size: 16),
                label: const Text("Leaderboard", style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Monthly Staff Excellence", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Ranking by current month work activity", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: GamificationService().getLeaderboard(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Staff';
                      final points = data['monthlyPoints'] ?? 0;
                      final level = data['level'] ?? 1;
                      final photo = data['photoBase64'] ?? "";

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("#${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: index < 3 ? Colors.amber.shade800 : Colors.grey)),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: photo.isNotEmpty ? MemoryImage(base64Decode(photo)) : null,
                                child: photo.isEmpty ? const Icon(Icons.person) : null,
                              ),
                            ],
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Level $level", style: const TextStyle(fontSize: 12)),
                          trailing: Text("$points pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF302B2C))),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildOrgButton(String title, IconData icon, VoidCallback onTap, {bool isSelected = false}) {
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
          final String? scannedCode = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );

          if (scannedCode != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scanned: $scannedCode'),
                backgroundColor: Colors.amber.shade900,
                duration: const Duration(seconds: 3),
              ),
            );
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