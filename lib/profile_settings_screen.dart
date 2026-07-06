import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'style_constants.dart';
import 'firestore_service.dart';
import 'housekeeping_task_screen.dart';
import 'housekeeping_activity_screen.dart';
import 'housekeeping_stock_distribution.dart';
import 'manager_purchases_screen.dart';
import 'manager_financial_screen.dart';
import 'manager_stock_tracking.dart';
import 'team_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'supervisor_room_assignment.dart';
import 'inventory_store_scan_page.dart';
import 'supplier_orders_screen.dart';
import 'supplier_item_price.dart';
import 'supplier_completed_screen.dart';
import 'login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final bool isReadOnly;
  final bool showBackButton; // New parameter

  const ProfileSettingsScreen({
    super.key,
    required this.userProfile,
    this.isReadOnly = false,
    this.showBackButton = false, // Default to false
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _companyNameController;
  List<String> _selectedCategories = [];
  List<String> _initialCategories = [];
  
  String _currentPhotoBase64 = "";
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool isDrawerOpen = false;

  final List<String> _categories = [
    'Linen & Bedding',
    'Toiletries Supplies',
    'Cleaning Supplies',
    'Housekeeping Equipment',
    'Room Amenities'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile['name'] ?? '');
    _phoneController = TextEditingController(text: widget.userProfile['phone'] ?? '');
    _addressController = TextEditingController(text: widget.userProfile['address'] ?? '');
    _companyNameController = TextEditingController(text: widget.userProfile['companyName'] ?? '');
    _currentPhotoBase64 = widget.userProfile['photoBase64'] ?? "";
    
    if (widget.userProfile['categories'] != null && widget.userProfile['categories'] is List) {
      _selectedCategories = List<String>.from(widget.userProfile['categories']);
    } else if (widget.userProfile['category'] != null) {
      _selectedCategories = [widget.userProfile['category']];
    }
    _initialCategories = List<String>.from(_selectedCategories);
  }

  void _showFullScreenQR() {
    final String staffId = widget.userProfile['staffId'] ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Staff Digital ID", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF302B2C))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: staffId,
                  version: QrVersions.auto,
                  size: 250.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(staffId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.amber)),
              const SizedBox(height: 10),
              const Text("Present this QR for scanning at the store station", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF302B2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _currentPhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _currentPhotoBase64 = "";
    });
  }

  void _showImageOptions() {
    bool isSupplier = widget.userProfile['role'] == 'Supplier';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (isSupplier)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Please put your company logo or image.",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                  textAlign: TextAlign.center,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(isSupplier ? 'Change Company Logo' : 'Change Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (_currentPhotoBase64.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(isSupplier ? 'Remove Logo' : 'Remove Photo', style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _didCategoriesChange() {
    if (_selectedCategories.length != _initialCategories.length) return true;
    for (var cat in _selectedCategories) {
      if (!_initialCategories.contains(cat)) return true;
    }
    return false;
  }

  Future<void> _saveProfileChanges() async {
    if (widget.userProfile['role'] == 'Supplier' && _didCategoriesChange()) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Confirm Changes", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("You have modified your Supplies Categories. Are you sure you want to update them?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
              child: const Text("Yes, Update", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);

    try {
      final String email = widget.userProfile['email'];
      final String staffId = widget.userProfile['staffId'] ?? 'UNKNOWN';
      
      final Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'photoBase64': _currentPhotoBase64,
      };

      if (widget.userProfile['role'] == 'Supplier') {
        updatedData['companyName'] = _companyNameController.text.trim();
        updatedData['categories'] = _selectedCategories;
      }

      await FirestoreService().updateUserInCloud(
        email: email,
        staffId: staffId,
        updatedData: updatedData,
      );

      if (!kIsWeb) {
        final String uniqueId = widget.userProfile['username'] ?? email;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (_currentPhotoBase64.isEmpty) {
          await prefs.remove('manager_profile_path_$uniqueId');
        }
      }

      widget.userProfile.addAll(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile synced & saved to Staff Profiles!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, widget.userProfile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.userProfile['email'];
    if (email.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'status': isAvailable ? 'Available' : 'Not Available',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSupplier = widget.userProfile['role'] == 'Supplier';
    ImageProvider? avatarImage;
    if (_currentPhotoBase64.isNotEmpty) {
      avatarImage = MemoryImage(base64Decode(_currentPhotoBase64));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Personal Settings", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: widget.showBackButton 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            )
          : IconButton(
              icon: const Icon(Icons.list, color: Colors.black87),
              onPressed: () => setState(() => isDrawerOpen = true),
            ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: widget.isReadOnly ? null : _showImageOptions,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: avatarImage,
                                    child: avatarImage == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                                  ),
                                ),
                                if (!widget.isReadOnly)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _showImageOptions,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                        child: const Icon(Icons.edit, size: 20, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (widget.userProfile['staffId'] != null) ...[
                              const SizedBox(width: 30),
                              GestureDetector(
                                onTap: _showFullScreenQR,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      QrImageView(
                                        data: widget.userProfile['staffId'],
                                        version: QrVersions.auto,
                                        size: 80.0,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                          child: const Icon(Icons.fullscreen, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSupplier && (widget.userProfile['companyName']?.toString().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            widget.userProfile['companyName'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 25),
                      
                      _buildInfoLabel("Staff ID"),
                      _buildReadOnlyField(widget.userProfile['staffId'] ?? 'N/A'),
                      
                      const SizedBox(height: 15),
                      
                      _buildInfoLabel("Email Address"),
                      _buildReadOnlyField(widget.userProfile['email'] ?? 'N/A'),
                      
                      const SizedBox(height: 25),
                      const Divider(),
                      const SizedBox(height: 15),
                      
                      _buildEditableField(isSupplier ? "PIC Name" : "Full Name", _nameController, Icons.person, enabled: !widget.isReadOnly),
                      
                      if (isSupplier) ...[
                        _buildCategorySelection(),
                      ],

                      _buildEditableField("Phone Number", _phoneController, Icons.phone, enabled: !widget.isReadOnly),
                      _buildEditableField("Home Address", _addressController, Icons.location_on, maxLines: 3, enabled: !widget.isReadOnly),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (!widget.isReadOnly)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : _saveProfileChanges,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Save Changes",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ),
            ],
          ),
          if (isDrawerOpen) _buildDrawerOverlay(MediaQuery.of(context).size.width),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoLabel("Supplies Categories (Select Multiple)"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _categories.map((String category) {
              bool isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                selected: isSelected,
                onSelected: widget.isReadOnly ? null : (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                selectedColor: Colors.amber.shade800,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerOverlay(double screenWidth) {
    String role = widget.userProfile['role'] ?? '';

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
              _buildDrawerItem(Icons.home, "Home", onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
              
              if (role == 'Manager') ...[
                _buildDrawerItem(Icons.shopping_bag, "Purchases", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerPurchasesScreen(managerProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.analytics, "Financial", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerFinancialScreen(managerProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerStockTracking(managerProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.people, "Team", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.userProfile)));
                }),
              ] else if (role == 'Supervisor') ...[
                _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorInventoryScreen(supervisorProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.userProfile)));
                }),
                _buildDrawerItem(
                  Icons.assignment_ind_outlined,
                  "Room Assignment",
                  onTap: () {
                    setState(() => isDrawerOpen = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupervisorRoomAssignment(supervisorProfile: widget.userProfile),
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
                        builder: (context) => InventoryStoreScanPage(supervisorProfile: widget.userProfile),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorStockTracking(supervisorProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.people, "Team", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.userProfile)));
                }),
              ]
else if (role == 'Housekeeping') ...[
                _buildDrawerItem(Icons.assignment_outlined, "Task", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HousekeepingTaskScreen(housekeepingProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.inventory_2_outlined, "Stock Distribution", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HousekeepingStockDistribution(housekeepingProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.history, "My Activity", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HousekeepingActivityScreen(housekeepingProfile: widget.userProfile)));
                }),
              ] else if (role == 'Supplier') ...[
                _buildDrawerItem(Icons.shopping_cart_outlined, "Orders", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupplierOrdersScreen(supplierProfile: widget.userProfile, initialFilter: "Active Order")));
                }),
                _buildDrawerItem(Icons.sell_outlined, "Item Price", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupplierItemPrice(supplierProfile: widget.userProfile)));
                }),
                _buildDrawerItem(Icons.assignment_turned_in_outlined, "Completed", onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupplierCompletedScreen(supplierProfile: widget.userProfile)));
                }),
              ],

              _buildDrawerItem(role == 'Supplier' ? Icons.settings_outlined : Icons.settings, "Settings", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
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
      decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
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

  Widget _buildInfoLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildReadOnlyFieldWithIcon(String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoLabel(label),
          TextField(
            controller: controller,
            maxLines: maxLines,
            enabled: enabled,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.amber.shade800),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
