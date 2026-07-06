import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'gamification_service.dart';
import 'profile_settings_screen.dart';
import 'housekeeping_task_screen.dart';
import 'housekeeping_activity_screen.dart';
import 'housekeeping_item_page.dart';
import 'housekeeping_dashboard.dart';
import 'login_screen.dart';

class HousekeepingStockDistribution extends StatefulWidget {
  final Map<String, dynamic> housekeepingProfile;
  const HousekeepingStockDistribution({super.key, required this.housekeepingProfile});

  @override
  State<HousekeepingStockDistribution> createState() => _HousekeepingStockDistributionState();
}

class _HousekeepingStockDistributionState extends State<HousekeepingStockDistribution> {
  final FocusNode _focusNode = FocusNode();
  String _inputBuffer = "";
  
  String searchQuery = "";
  bool isDrawerOpen = false;
  String selectedCategory = "Linen & Bedding";
  Map<String, Map<String, dynamic>> cart = {}; // stockId -> {name, qty}

  final List<String> categories = [
    'Linen & Bedding',
    'Toiletries Supplies',
    'Cleaning Supplies',
    'Housekeeping Equipment',
    'Room Amenities'
  ];

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
          _processScannedBarcode(_inputBuffer);
          _inputBuffer = "";
        }
      } else {
        if (event.character != null) {
          _inputBuffer += event.character!;
        }
      }
    }
  }

  Future<void> _processScannedBarcode(String code) async {
    code = code.trim();
    if (code.isEmpty) return;

    try {
      // 1. Try to find item by barcode field
      var itemQuery = await FirebaseFirestore.instance
          .collection('inventory')
          .where('barcode', isEqualTo: code)
          .get();

      DocumentSnapshot? itemDoc;
      if (itemQuery.docs.isNotEmpty) {
        itemDoc = itemQuery.docs.first;
      } else {
        // Fallback: check if the code is the document ID
        var docById = await FirebaseFirestore.instance.collection('inventory').doc(code).get();
        if (docById.exists) {
          itemDoc = docById;
        }
      }

      if (itemDoc != null) {
        final data = itemDoc.data() as Map<String, dynamic>;
        final String name = data['name'] ?? "Unknown Item";
        final int availableQty = data['availableQty'] ?? 0;

        if (availableQty <= 0) {
          _showOutOfStockDialog(name);
          return;
        }

        setState(() {
          int currentInCart = cart[itemDoc!.id]?['qty'] ?? 0;
          if (currentInCart + 1 > availableQty) {
            _showErrorSnackBar("Only $availableQty units available in stock.");
          } else if (currentInCart + 1 > 5) {
            _showErrorSnackBar("Staff cannot get more than 5 units per day.");
          } else {
            cart[itemDoc.id] = {
              'name': name,
              'qty': currentInCart + 1,
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Added 1 $name to cart"), backgroundColor: Colors.blue, duration: const Duration(seconds: 1)),
            );
          }
        });
      } else {
        _showErrorDialog("Item Not Found", "The scanned barcode '$code' does not match any items in the inventory.");
      }
    } catch (e) {
      _showErrorSnackBar("Scan Error: $e");
    } finally {
      _focusNode.requestFocus();
    }
  }

  void _showOutOfStockDialog(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text("OUT OF STOCK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("Sorry, '$name' is currently unavailable and cannot be distributed until restocked."),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF302B2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Dismiss")),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
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
                          _buildReloadButton(),
                          const SizedBox(height: 15),
                          _buildCategoryFilter(),
                          const SizedBox(height: 25),
                          _buildStockListHeader(),
                          _buildStockList(),
                          const SizedBox(height: 100), // Space for sticky button
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildCompleteButton(),
            ),
            if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.list, size: 30),
            onPressed: () => setState(() => isDrawerOpen = true),
          ),
          const Text("Stock Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          GestureDetector(
            onTap: _showCartSummary,
            child: Stack(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 30, color: Colors.black87),
                if (cart.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        "${cart.length}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
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
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Refreshing data..."), backgroundColor: Color(0xFFC98A6B)),
          );
        },
        icon: const Icon(Icons.refresh, color: Color(0xFFC98A6B), size: 18),
        label: const Text("Reload Data", style: TextStyle(color: Color(0xFFC98A6B), fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          bool isSelected = selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8D5B3E) : const Color(0xFFD2B49C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockListHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        selectedCategory,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF302B2C)),
      ),
    );
  }

  Widget _buildStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .where('category', isEqualTo: selectedCategory)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var items = snapshot.data!.docs.where((doc) {
          String name = (doc['name'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        if (items.isEmpty) {
          return const Center(child: Text("No items found in this category."));
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              var data = items[index].data() as Map<String, dynamic>;
              int availableQty = data['availableQty'] ?? 0;
              bool isOutOfStock = availableQty <= 0;

              return ListTile(
                onTap: () async {
                  if (isOutOfStock) {
                    _showOutOfStockDialog(data['name'] ?? "This item");
                    return;
                  }
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HousekeepingItemPage(
                        stockId: items[index].id,
                        stockData: data,
                        housekeepingProfile: widget.housekeepingProfile,
                        initialQty: cart[items[index].id]?['qty'] ?? 0,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      if (result['qty'] > 0) {
                        cart[items[index].id] = {
                          'name': data['name'],
                          'qty': result['qty'],
                        };
                      } else {
                        cart.remove(items[index].id);
                      }
                    });
                  }
                },
                title: Text(
                  data['name'] ?? "Unknown", 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock ? Colors.grey : Colors.black87
                  )
                ),
                subtitle: Text(
                  isOutOfStock ? "OUT OF STOCK" : (data['location'] ?? "No Location"), 
                  style: TextStyle(
                    color: isOutOfStock ? Colors.red : Colors.grey, 
                    fontSize: 12,
                    fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal
                  )
                ),
                trailing: isOutOfStock 
                  ? const Icon(Icons.block, size: 14, color: Colors.red)
                  : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: cart.isEmpty ? null : _showConfirmationPopup,
        child: const Text("Complete", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showCartSummary() {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cart is empty")));
      return;
    }
    _showConfirmationPopup();
  }

  void _showConfirmationPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cart Items Confirmation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: cart.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.value['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text("x${e.value['qty']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            onPressed: () async {
              try {
                final firestore = FirebaseFirestore.instance;
                final batch = firestore.batch();
                List<Map<String, dynamic>> loggedItems = [];

                for (var entry in cart.entries) {
                  String stockId = entry.key;
                  int qtyTaken = entry.value['qty'];
                  String name = entry.value['name'];

                  DocumentReference stockRef = firestore.collection('inventory').doc(stockId);
                  DocumentSnapshot stockSnap = await stockRef.get();

                  if (stockSnap.exists) {
                    var data = stockSnap.data() as Map<String, dynamic>;
                    int currentAvail = data['availableQty'] ?? 0;
                    int totalQty = data['totalQty'] ?? 1;
                    int newAvail = currentAvail - qtyTaken;
                    if (newAvail < 0) newAvail = 0;
                    int newPercentage = ((newAvail / totalQty) * 100).round();

                    batch.update(stockRef, {
                      'availableQty': newAvail,
                      'percentage': newPercentage,
                    });

                    loggedItems.add({
                      'itemName': name,
                      'quantity': qtyTaken,
                    });
                  }
                }

                // 2. Create Log Entry
                DocumentReference logRef = firestore.collection('stock_distribution_logs').doc();
                batch.set(logRef, {
                  'staffName': widget.housekeepingProfile['name'] ?? 'Unknown',
                  'staffEmail': widget.housekeepingProfile['email'] ?? '',
                  'timestamp': FieldValue.serverTimestamp(),
                  'items': loggedItems,
                });

                await batch.commit();

                // 3. Award Gamification Points
                for (var item in loggedItems) {
                  await GamificationService().awardStockScan(
                    widget.housekeepingProfile['email'], 
                    item['itemName']
                  );
                }

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  setState(() => cart.clear());
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Distribution Completed Successfully!"), backgroundColor: Colors.green)
                  );

                  // 3. Redirect to Dashboard
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => HousekeepingDashboard(housekeepingProfile: widget.housekeepingProfile)),
                    (route) => route.isFirst,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          )
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
              _buildDrawerItem(Icons.assignment_outlined, "Task", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HousekeepingTaskScreen(housekeepingProfile: widget.housekeepingProfile)));
              }),
              _buildDrawerItem(Icons.inventory_2_outlined, "Stock Distribution", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
              _buildDrawerItem(Icons.history, "My Activity", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HousekeepingActivityScreen(housekeepingProfile: widget.housekeepingProfile)));
              }),
              _buildDrawerItem(Icons.settings, "Settings", onTap: () async {
                setState(() => isDrawerOpen = false);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.housekeepingProfile)));
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
