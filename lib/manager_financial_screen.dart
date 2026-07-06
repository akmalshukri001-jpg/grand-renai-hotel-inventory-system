import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'manager_purchases_screen.dart';
import 'team_screen.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';

import 'manager_financial_stats_screen.dart';
import 'manager_transaction_history.dart';
import 'manager_funds_screen.dart';
import 'manager_funds_history_screen.dart';
import 'manager_stock_tracking.dart';
import 'manager_supplier_profile.dart';

class ManagerFinancialScreen extends StatefulWidget {
  final Map<String, dynamic> managerProfile;
  final Map<String, dynamic>? successTransaction; // Transaction info to show success dialog

  const ManagerFinancialScreen({
    super.key,
    required this.managerProfile,
    this.successTransaction,
  });

  @override
  State<ManagerFinancialScreen> createState() => _ManagerFinancialScreenState();
}

class _ManagerFinancialScreenState extends State<ManagerFinancialScreen> {
  bool isDrawerOpen = false;
  double hotelBudget = 30000.0;
  String hotelLogoUrl = ""; // Holds the Base64 data for the Hotel Logo

  // Stats for the history section
  double weeklyTotal = 0;
  int weeklyCount = 0;
  double monthlyTotal = 0;
  int monthlyCount = 0;
  double annualTotal = 0;
  int annualCount = 0;

  // Last 4 months stats for chart
  Map<String, double> lastMonthsSpending = {};
  List<String> monthNames = [];

  @override
  void initState() {
    super.initState();
    _prepareMonthNames();
    _listenToFinancialData();
    _listenToHotelLogoData();

    // Show success dialog if transaction info is passed
    if (widget.successTransaction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessDialog(
          widget.successTransaction!['txnId'],
          widget.successTransaction!['time'],
        );
      });
    }
  }

  void _showSuccessDialog(String txnId, DateTime time) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text("Transfer Successful", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildDialogRow("Transaction ID", txnId),
            _buildDialogRow("Time", DateFormat('hh:mm a').format(time)),
            _buildDialogRow("Date", DateFormat('dd MMM yyyy').format(time)),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC98A6B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
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

  void _prepareMonthNames() {
    DateTime now = DateTime.now();
    for (int i = 3; i >= 0; i--) {
      DateTime d = DateTime(now.year, now.month - i, 1);
      monthNames.add(DateFormat('MMM').format(d).toUpperCase());
    }
  }

  void _listenToFinancialData() {
    // Listen to budget
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

    // We will store the latest snapshots locally to combine them
    QuerySnapshot? latestPayments;
    QuerySnapshot? latestFunds;

    void processCombinedData() {
      // Allow processing even if one collection hasn't loaded yet
      var paymentDocs = latestPayments?.docs ?? [];
      var fundDocs = latestFunds?.docs ?? [];

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      DateTime startOfMonth = DateTime(today.year, today.month, 1);
      DateTime startOfYear = DateTime(today.year, 1, 1);

      double wT = 0, mT = 0, aT = 0;
      int wC = 0, mC = 0, aC = 0;
      Map<String, double> mSpending = {for (var m in monthNames) m: 0.0};

      // Process Payments
      for (var doc in paymentDocs) {
        var data = doc.data() as Map<String, dynamic>;
        double amt = (data['totalAmount'] ?? 0).toDouble();
        Timestamp ts = data['timestamp'] ?? Timestamp.now();
        DateTime date = ts.toDate();

        if (!date.isBefore(startOfWeek)) { wT += amt; wC++; }
        if (!date.isBefore(startOfMonth)) { mT += amt; mC++; }
        if (!date.isBefore(startOfYear)) { aT += amt; aC++; }

        String mName = DateFormat('MMM').format(date).toUpperCase();
        if (mSpending.containsKey(mName)) {
          mSpending[mName] = mSpending[mName]! + amt;
        }
      }

      // Process Funds
      for (var doc in fundDocs) {
        var data = doc.data() as Map<String, dynamic>;
        double amt = (data['amountAdded'] ?? 0).toDouble();
        Timestamp ts = data['timestamp'] ?? Timestamp.now();
        DateTime date = ts.toDate();

        if (!date.isBefore(startOfWeek)) { wT += amt; wC++; }
        if (!date.isBefore(startOfMonth)) { mT += amt; mC++; }
        if (!date.isBefore(startOfYear)) { aT += amt; aC++; }
      }

      if (mounted) {
        setState(() {
          weeklyTotal = wT;
          weeklyCount = wC;
          monthlyTotal = mT;
          monthlyCount = mC;
          annualTotal = aT;
          annualCount = aC;
          lastMonthsSpending = mSpending;
        });
      }
    }

    FirebaseFirestore.instance.collection('payments').snapshots().listen((snap) {
      latestPayments = snap;
      processCombinedData();
    });

    FirebaseFirestore.instance.collection('funds_history').snapshots().listen((snap) {
      latestFunds = snap;
      processCombinedData();
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildHeaderRow(),
                  const SizedBox(height: 25),
                  _buildBudgetCard(),
                  const SizedBox(height: 25),
                  _buildActionButtons(),
                  const SizedBox(height: 30),
                  _buildStatisticsSection(),
                  const SizedBox(height: 30),
                  _buildPurchasesHistorySection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (isDrawerOpen) _buildDrawerOverlay(screenWidth),
        ],
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

        return Row(
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
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile)));
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: photoBase64.isNotEmpty ? MemoryImage(base64Decode(photoBase64)) : null,
                child: photoBase64.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFD2B49C),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFB06138), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Hotel Budget", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                Text("Grand Renai Inventory", style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Text(
            "RM ${NumberFormat('#,##0.00').format(hotelBudget)}",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManagerFundsScreen(managerProfile: widget.managerProfile))),
          child: _buildCircularAction(Icons.add_card, "Add Funds"),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerFundsHistoryScreen())),
          child: _buildCircularAction(Icons.history_edu_outlined, "Funds History"),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerSupplierProfile())),
          child: _buildCircularAction(Icons.groups_outlined, "Supplier"),
        ),
      ],
    );
  }

  Widget _buildCircularAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Icon(icon, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Statistic 2026", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerFinancialStatsScreen()));
              },
              child: const Text("See More", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 10, top: 10),
          child: Row(
            children: [
              // Y-Axis
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 4000; i >= 0; i -= 1000)
                    Text("RM ${i >= 1000 ? '${(i / 1000).toInt()}k' : '0'}", 
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20), // Spacer for X-axis labels
                ],
              ),
              const SizedBox(width: 10),
              // Chart Area (Bars + Background Lines)
              Expanded(
                child: Stack(
                  children: [
                    // Horizontal Grid Lines
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 0; i < 5; i++)
                          const Divider(height: 1, color: Colors.black12, thickness: 1),
                        const SizedBox(height: 20), // Spacer for X-axis
                      ],
                    ),
                    // Bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: monthNames.map((m) {
                        double amount = lastMonthsSpending[m] ?? 0.0;
                        double heightFactor = (amount / 4000).clamp(0.05, 1.0);
                        Color barColor = Colors.green;
                        if (amount > 3000) {
                          barColor = Colors.red;
                        } else if (amount > 2000) {
                          barColor = Colors.amber;
                        }
                        return _buildBar(m, heightFactor, barColor, amount);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildBar(String month, double heightFactor, Color color, double amount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (amount > 0)
          Text("RM${(amount/1000).toStringAsFixed(1)}k", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 160 * heightFactor,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Text(month, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
      ],
    );
  }

  Widget _buildPurchasesHistorySection() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Transaction History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildHistoryCard("Weekly Transaction", weeklyTotal, weeklyCount, 
            today.subtract(Duration(days: today.weekday - 1))),
        const SizedBox(height: 15),
        _buildHistoryCard("Monthly Transaction", monthlyTotal, monthlyCount, 
            DateTime(today.year, today.month, 1)),
        const SizedBox(height: 15),
        _buildHistoryCard("Annual Transaction", annualTotal, annualCount, 
            DateTime(today.year, 1, 1)),
      ],
    );
  }

  Widget _buildHistoryCard(String title, double total, int transactions, DateTime startDate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Transaction : $transactions", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManagerTransactionHistoryScreen(
                    title: title,
                    startDate: startDate,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text("See All", style: TextStyle(color: Colors.white, fontSize: 12)),
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
              _buildDrawerItem(Icons.shopping_bag, "Purchases", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerPurchasesScreen(managerProfile: widget.managerProfile)));
              }),
              _buildDrawerItem(Icons.analytics, "Financial", isActive: true, onTap: () => setState(() => isDrawerOpen = false)),
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
              _buildDrawerItem(Icons.people, "Team", onTap: () {
                setState(() => isDrawerOpen = false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TeamScreen(currentUserProfile: widget.managerProfile)));
              }),
              _buildDrawerItem(Icons.settings, "Settings", onTap: () async {
                setState(() => isDrawerOpen = false);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(userProfile: widget.managerProfile)));
                setState(() {});
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
