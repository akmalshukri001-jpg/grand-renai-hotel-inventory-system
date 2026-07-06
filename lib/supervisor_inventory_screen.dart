import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'profile_settings_screen.dart';
import 'scanner_screen.dart';
import 'team_screen.dart';
import 'supervisor_request_stock.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'supervisor_room_assignment.dart';
import 'inventory_store_scan_page.dart';
import 'login_screen.dart';

class SupervisorInventoryScreen extends StatefulWidget {
  final Map<String, dynamic> supervisorProfile;
  const SupervisorInventoryScreen({super.key, required this.supervisorProfile});

  @override
  State<SupervisorInventoryScreen> createState() => _SupervisorInventoryScreenState();
}

class _SupervisorInventoryScreenState extends State<SupervisorInventoryScreen> {
  String searchQuery = "";
  bool isDrawerOpen = false;
  final ImagePicker _picker = ImagePicker();
  
  // 💡 Local cache for pre-decoded images to improve performance
  final Map<String, Uint8List> _decodedImageCache = {};
  final Set<String> _uploadingIds = {};

  // Real-time stats
  int lowStockCount = 0;
  int totalItemsCount = 0;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  void _fetchStats() {
    // 1. Listen to Total Items
    FirebaseFirestore.instance
        .collection('inventory')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          totalItemsCount = snapshot.docs.length;
        });
      }
    });

    // 2. Listen to Low Stock Items
    FirebaseFirestore.instance
        .collection('inventory')
        .where('percentage', isLessThanOrEqualTo: 20)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          lowStockCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _updateUserStatus(bool isAvailable) async {
    final String email = widget.supervisorProfile['email'];
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildSearchField(),
                        if (searchQuery.isEmpty) ...[
                          _buildReloadButton(),
                          const SizedBox(height: 20),
                          _buildStatsGrid(),
                          const SizedBox(height: 25),
                        ] else
                          const SizedBox(height: 20),
                        _buildStockListHeader(),
                        _buildStockList(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: _buildActionButtons(),
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
      stream: FirebaseFirestore.instance.collection('users').doc(widget.supervisorProfile['email']).snapshots(),
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
              const Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              Row(
                children: [
                  IconButton(
                    icon: _isPrinting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print_outlined, color: Colors.black87),
                    tooltip: "Print All Barcodes",
                    onPressed: _isPrinting ? null : _generateAllBarcodesPDF,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.supervisorProfile)),
                      );
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: photoBase64.isNotEmpty
                              ? MemoryImage(base64Decode(photoBase64))
                              : null,
                          child: photoBase64.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        const Text("Supervisor", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateAllBarcodesPDF() async {
    setState(() => _isPrinting = true);
    try {
      final pdf = pw.Document();
      final inventorySnap = await FirebaseFirestore.instance.collection('inventory').get();
      
      if (inventorySnap.docs.isEmpty) {
        _showSnackBar("No inventory items found to print", Colors.orange);
        return;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Grand Renai - Inventory Barcodes", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 15,
                runSpacing: 15,
                children: inventorySnap.docs.map((doc) {
                  final data = doc.data();
                  final String name = data['name'] ?? "Unknown";
                  final String id = doc.id;
                  
                  return pw.Container(
                    width: 160,
                    height: 100,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 1, overflow: pw.TextOverflow.clip),
                        pw.SizedBox(height: 5),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: id,
                          width: 60,
                          height: 60,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(id, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Inventory_Barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      _showSnackBar("Error generating PDF: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
        decoration: const InputDecoration(
          hintText: "Search Stock",
          prefixIcon: Icon(Icons.search, color: Color(0xFFC98A6B)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildReloadButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          _fetchStats();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Refreshing data..."), backgroundColor: Color(0xFFC98A6B)),
          );
        },
        icon: const Icon(Icons.refresh, color: Color(0xFFC98A6B), size: 18),
        label: const Text("Reload Data", style: TextStyle(color: Color(0xFFC98A6B), fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard("Low Stock Items", lowStockCount.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard("Total Items", totalItemsCount.toString())),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFC98A6B),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: const Color(0xFFC98A6B).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF302B2C))),
          ),
        ],
      ),
    );
  }

  Widget _buildStockListHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: const BoxDecoration(
        color: Color(0xFFD2B49C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: const Text("Stock Level Overview", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var stocks = snapshot.data!.docs;
        var filteredStocks = stocks.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['name'] ?? "").toString().toLowerCase();
          String location = (data['location'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery) || location.contains(searchQuery);
        }).toList();

        filteredStocks.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          
          int pA = dataA['percentage'] ?? 0;
          int pB = dataB['percentage'] ?? 0;
          return pA.compareTo(pB);
        });

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: filteredStocks.map((doc) => _buildStockTile(doc)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStockTile(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    int percentage = data['percentage'] ?? 0;
    String photoBase64 = data['photoBase64'] ?? "";
    bool isUploading = _uploadingIds.contains(doc.id);
    
    Color pColor = percentage <= 30 ? Colors.red : (percentage <= 50 ? Colors.amber : Colors.green);

    // 💡 Handle image display (cached or cloud)
    ImageProvider? imageProvider;
    if (_decodedImageCache.containsKey(doc.id)) {
      imageProvider = MemoryImage(_decodedImageCache[doc.id]!);
    } else if (photoBase64.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _updateStockImage(doc.id),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                ),
                child: isUploading 
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : (imageProvider == null ? const Icon(Icons.add_a_photo_outlined, color: Colors.grey) : null),
              ),
            ),
          ),
          
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SupervisorRequestStock(stockId: doc.id, stockData: data, supervisorProfile: widget.supervisorProfile)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(data['location'] ?? "No Location", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("$percentage%", style: TextStyle(color: pColor, fontWeight: FontWeight.bold, fontSize: 20)),
                        Text("Qty: ${data['availableQty'] ?? 0} / ${data['totalQty'] ?? 0}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStockImage(String docId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 250, // 💡 Minimal size for extreme reliability
        maxHeight: 250,
        imageQuality: 50,
      );

      if (image != null) {
        setState(() => _uploadingIds.add(docId));

        final bytes = await image.readAsBytes();
        
        setState(() {
          _decodedImageCache[docId] = bytes; // Instant Local Update
        });

        String base64 = base64Encode(bytes);
        
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(docId)
            .update({'photoBase64': base64});

        if (mounted) {
          setState(() => _uploadingIds.remove(docId));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock image updated successfully."), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingIds.remove(docId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _addNewStockDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add New Stock"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  void _addNewStockDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController locController = TextEditingController();
    TextEditingController totalController = TextEditingController();
    TextEditingController availController = TextEditingController();
    String? selectedCategory;

    final List<String> categories = [
      'Linen & Bedding',
      'Toiletries Supplies',
      'Cleaning Supplies',
      'Housekeeping Equipment',
      'Room Amenities'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add New Stock", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField("Stock Name", nameController, Icons.inventory),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: const Text("Select Category"),
                        value: selectedCategory,
                        isExpanded: true,
                        items: categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            selectedCategory = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField("Location (e.g. Lobby)", locController, Icons.place),
                  const SizedBox(height: 12),
                  _buildDialogField("Total Quantity", totalController, Icons.list_alt, isNumeric: true),
                  const SizedBox(height: 12),
                  _buildDialogField("Available Quantity", availController, Icons.check_circle_outline, isNumeric: true),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC98A6B)),
                onPressed: () async {
                  if (selectedCategory == null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Missing Selection", style: TextStyle(color: Colors.red)),
                        content: const Text("Please select a Stock Category before adding."),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
                      ),
                    );
                    return;
                  }

                  if (nameController.text.isNotEmpty && totalController.text.isNotEmpty) {
                    int total = int.tryParse(totalController.text) ?? 1;
                    int avail = int.tryParse(availController.text) ?? 0;
                    int percentage = ((avail / total) * 100).round();
                    
                    // 1. Add to Inventory
                    var newStockRef = await FirebaseFirestore.instance.collection('inventory').add({
                      'name': nameController.text,
                      'category': selectedCategory,
                      'location': locController.text,
                      'totalQty': total,
                      'availableQty': avail,
                      'percentage': percentage,
                      'photoBase64': "",
                    });

                    // 2. Create Stock Log entry
                    await FirebaseFirestore.instance.collection('stock_logs').add({
                      'action': "ADDED",
                      'itemName': nameController.text,
                      'stockId': newStockRef.id,
                      'totalQty': total,
                      'availableQty': avail,
                      'staffId': widget.supervisorProfile['staffId'] ?? 'SUP-UNKNOWN',
                      'staffName': widget.supervisorProfile['name'] ?? 'Supervisor',
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Add Item", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildDrawerOverlay(double screenWidth) {
    return Stack(
      children: [
        GestureDetector(onTap: () => setState(() => isDrawerOpen = false), child: Container(color: Colors.black.withOpacity(0.3))),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: screenWidth * 0.55,
          height: double.infinity,
          color: const Color(0xFFC98A6B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              _buildDrawerItem(Icons.home_outlined, "Home", onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
              _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(
                Icons.assignment_ind_outlined,
                "Room Assignment",
                onTap: () {
                  setState(() => isDrawerOpen = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorRoomAssignment(supervisorProfile: widget.supervisorProfile),
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
                      builder: (context) => InventoryStoreScanPage(supervisorProfile: widget.supervisorProfile),
                    ),
                  );
                },
              ),
              _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupervisorStockTracking(supervisorProfile: widget.supervisorProfile),
                  ),
                );
              }),
              _buildDrawerItem(Icons.people_outline, "Team", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.settings_outlined, "Settings", onTap: () async {
                setState(() => isDrawerOpen = false);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.supervisorProfile)));
              }),
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
      decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
          foregroundColor: Colors.black87,
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
        icon: const Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
        label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFC98A6B), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
