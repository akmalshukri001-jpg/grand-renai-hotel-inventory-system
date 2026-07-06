import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'profile_settings_screen.dart';
import 'team_screen.dart';
import 'supervisor_inventory_screen.dart';
import 'supervisor_approval_screen.dart';
import 'supervisor_stock_tracking.dart';
import 'supervisor_room_assignment.dart';
import 'login_screen.dart';

class InventoryStoreScanPage extends StatefulWidget {
  final Map<String, dynamic> supervisorProfile;
  const InventoryStoreScanPage({super.key, required this.supervisorProfile});

  @override
  State<InventoryStoreScanPage> createState() => _InventoryStoreScanPageState();
}

class _InventoryStoreScanPageState extends State<InventoryStoreScanPage> {
  final FocusNode _focusNode = FocusNode();
  String _inputBuffer = "";
  
  Map<String, dynamic>? _currentStaff;
  Map<String, Map<String, dynamic>> _scannedItems = {}; // barcode -> {name, qty, stockId, data}
  
  bool _isProcessing = false;
  bool isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_inputBuffer.isNotEmpty) {
          _processScannedCode(_inputBuffer);
          _inputBuffer = "";
        }
      } else {
        if (event.character != null) {
          _inputBuffer += event.character!;
        }
      }
    }
  }

  Future<void> _processScannedCode(String code) async {
    code = code.trim();
    if (code.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      if (_currentStaff == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('staffId', isEqualTo: code)
            .get();

        if (userDoc.docs.isNotEmpty) {
          setState(() {
            _currentStaff = userDoc.docs.first.data();
          });
          _showSnackBar("Staff Identified: ${_currentStaff!['name']}", Colors.green);
        } else {
          _showSnackBar("Unknown Staff ID: $code", Colors.red);
        }
      } else {
        var itemQuery = await FirebaseFirestore.instance
            .collection('inventory')
            .where('barcode', isEqualTo: code)
            .get();

        DocumentSnapshot? itemDoc;
        if (itemQuery.docs.isNotEmpty) {
          itemDoc = itemQuery.docs.first;
        } else {
          var docById = await FirebaseFirestore.instance.collection('inventory').doc(code).get();
          if (docById.exists) {
            itemDoc = docById;
          }
        }

        if (itemDoc != null) {
          final data = itemDoc.data() as Map<String, dynamic>;
          final String name = data['name'] ?? "Unknown Item";
          final String stockId = itemDoc.id;
          final int availableQty = data['availableQty'] ?? 0;

          if (availableQty <= 0) {
            _showErrorDialog("OUT OF STOCK", "The item '$name' is currently unavailable and cannot be distributed.");
            return;
          }

          setState(() {
            if (_scannedItems.containsKey(code)) {
              _scannedItems[code]!['qty'] += 1;
            } else {
              _scannedItems[code] = {
                'name': name,
                'qty': 1,
                'stockId': stockId,
                'data': data,
              };
            }
          });
          _showSnackBar("Added: $name", Colors.blue);
        } else {
          _showErrorDialog("Item Not Found", "The scanned barcode '$code' does not exist in the inventory.");
        }
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isProcessing = false);
      _focusNode.requestFocus();
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF302B2C)),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _confirmDistribution() async {
    if (_currentStaff == null || _scannedItems.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      List<Map<String, dynamic>> loggedItems = [];

      for (var entry in _scannedItems.values) {
        String stockId = entry['stockId'];
        int qtyTaken = entry['qty'];
        var data = entry['data'];

        DocumentReference stockRef = FirebaseFirestore.instance.collection('inventory').doc(stockId);
        
        int currentAvail = data['availableQty'] ?? 0;
        int totalQty = data['totalQty'] ?? 1;
        int newAvail = (currentAvail - qtyTaken).clamp(0, totalQty);
        int newPercentage = ((newAvail / totalQty) * 100).round();

        batch.update(stockRef, {
          'availableQty': newAvail,
          'percentage': newPercentage,
        });

        loggedItems.add({
          'itemName': entry['name'],
          'quantity': qtyTaken,
        });
      }

      DocumentReference logRef = FirebaseFirestore.instance.collection('stock_distribution_logs').doc();
      batch.set(logRef, {
        'staffName': _currentStaff!['name'] ?? 'Unknown',
        'staffEmail': _currentStaff!['email'] ?? '',
        'staffId': _currentStaff!['staffId'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'items': loggedItems,
        'stationSupervisor': widget.supervisorProfile['name'],
      });

      await batch.commit();
      
      _showSnackBar("Distribution Logged Successfully!", Colors.green);
      _resetSession();
    } catch (e) {
      _showSnackBar("Failed to save: $e", Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _resetSession() {
    setState(() {
      _currentStaff = null;
      _scannedItems.clear();
      _inputBuffer = "";
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text("Inventory Store Station (Scanner Mode)", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF302B2C),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => setState(() => isDrawerOpen = true),
          ),
          actions: [
            IconButton(onPressed: _resetSession, icon: const Icon(Icons.refresh), tooltip: "Reset Station"),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildStaffPanel(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _buildItemsPanel(),
                  ),
                ],
              ),
            ),
            if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
          ],
        ),
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
              _buildDrawerItem(Icons.home_outlined, "Home", onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
              _buildDrawerItem(Icons.inventory_2_outlined, "Inventory", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorInventoryScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.fact_check_outlined, "Approval", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorApprovalScreen(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.assignment_ind_outlined, "Room Assignment", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorRoomAssignment(supervisorProfile: widget.supervisorProfile)));
              }),
              _buildDrawerItem(Icons.settings_remote, "Inventory Store Station", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(Icons.track_changes, "Stock Tracking", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SupervisorStockTracking(supervisorProfile: widget.supervisorProfile)));
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
          // Update status logic
          await FirebaseFirestore.instance.collection('users').doc(widget.supervisorProfile['email']).update({
            'status': 'Not Available',
            'lastSeen': FieldValue.serverTimestamp(),
          });
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

  Widget _buildStaffPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          const Icon(Icons.person_pin, size: 80, color: Color(0xFFC98A6B)),
          const SizedBox(height: 20),
          if (_currentStaff == null) ...[
            const Text("WAITING FOR SCAN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 10),
            const Text("Please scan Housekeeping Staff QR Code", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ] else ...[
            Text(_currentStaff!['name'] ?? 'N/A', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("ID: ${_currentStaff!['staffId'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 10),
            Chip(label: Text(_currentStaff!['role'] ?? 'Staff'), backgroundColor: const Color(0xFFC98A6B).withOpacity(0.1)),
            const Divider(height: 40),
            const Text("Ready to scan items...", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
          const Spacer(),
          if (_currentStaff != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetSession,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                child: const Text("Cancel / Clear Staff"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Scanned Items", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Total Items: ${_scannedItems.length}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _scannedItems.isEmpty
                ? const Center(child: Text("No items scanned yet", style: TextStyle(color: Colors.grey)))
                : ListView(
                    children: _scannedItems.values.map((item) => _buildItemTile(item)).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          if (_scannedItems.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isProcessing ? null : _confirmDistribution,
                child: const Text("CONFIRM & RECORD DISTRIBUTION", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFFC98A6B), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Barcode: ${item['stockId']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
            child: Text("x ${item['qty']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () {
              setState(() {
                if (item['qty'] > 1) {
                  item['qty'] -= 1;
                } else {
                  _scannedItems.removeWhere((key, value) => value['stockId'] == item['stockId']);
                }
              });
            },
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          )
        ],
      ),
    );
  }
}
