import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_damaged_screen.dart';
import 'gamification_service.dart';

class RoomChecklistScreen extends StatefulWidget {
  final int roomNumber;
  final int level;
  final Map<String, dynamic> housekeepingProfile;

  const RoomChecklistScreen({
    super.key,
    required this.roomNumber,
    required this.level,
    required this.housekeepingProfile,
  });

  @override
  State<RoomChecklistScreen> createState() => _RoomChecklistScreenState();
}

class _RoomChecklistScreenState extends State<RoomChecklistScreen> {
  // Default checklist items and their quantities
  Map<String, int> checklist = {
    'Bedsheets': 1,
    'Pillowcases': 2,
    'Blanket': 1,
    'Towels': 2,
    'Shampoo': 2,
    'Soap': 2,
    'Tissue Rolls': 1,
    'Coffee Sachets': 2,
    'Tea Sachets': 2,
    'Creamer': 2,
    'Mineral Water': 1,
  };

  bool _isSaving = false;
  String status = "Pending";
  String handledBy = "";

  @override
  void initState() {
    super.initState();
    handledBy = widget.housekeepingProfile['name'] ?? "Staff";
    _fetchExistingData();
  }

  Future<void> _fetchExistingData() async {
    final doc = await FirebaseFirestore.instance
        .collection('housekeeping_tasks')
        .doc('level_${widget.level}')
        .collection('rooms')
        .doc('room_${widget.roomNumber}')
        .get();

    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        status = data['status'] ?? "Pending";
        if (status == "Completed") {
          handledBy = data['completedBy'] ?? handledBy;
        } else {
          handledBy = data['assignedToName'] ?? handledBy;
        }
        
        if (data.containsKey('checklist')) {
          Map<String, dynamic> savedChecklist = data['checklist'];
          savedChecklist.forEach((key, value) {
            if (checklist.containsKey(key)) {
              checklist[key] = value as int;
            }
          });
        }
      });
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);

    try {
      final roomRef = FirebaseFirestore.instance
          .collection('housekeeping_tasks')
          .doc('level_${widget.level}')
          .collection('rooms')
          .doc('room_${widget.roomNumber}');

      bool isNewCompletion = status != "Completed";

      await roomRef.set({
        'roomNumber': widget.roomNumber,
        'level': widget.level,
        'status': 'Completed',
        'completedBy': widget.housekeepingProfile['name'],
        'completedByEmail': widget.housekeepingProfile['email'],
        'staffId': widget.housekeepingProfile['staffId'],
        'role': widget.housekeepingProfile['role'],
        'timestamp': FieldValue.serverTimestamp(),
        'checklist': checklist,
      }, SetOptions(merge: true));

      if (isNewCompletion) {
        await GamificationService().awardRoomCompletion(
          widget.housekeepingProfile['email'], 
          widget.roomNumber
        );
      }

      if (mounted) {
        String msg = isNewCompletion 
            ? "Successfully completed room ${widget.roomNumber}" 
            : "Successfully updated room ${widget.roomNumber}";
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5EEF4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildRoomStatusCard(),
                    const SizedBox(height: 25),
                    _buildChecklistContainer(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Row(
            children: [
              const Text('🏨 ', style: TextStyle(fontSize: 18)),
              const Text("Grand Renai Hotel Inventory", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildRoomStatusCard() {
    bool isCompleted = status == "Completed";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.cancel,
            color: isCompleted ? Colors.green : Colors.red,
            size: 45,
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Room ${widget.roomNumber}", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(isCompleted ? "Completed by " : "Pending by ",
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(handledBy, 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD2B49C),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          ...checklist.keys.map((item) => _buildChecklistItem(item)).toList(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDamagedScreen(
                          roomNumber: widget.roomNumber,
                          level: widget.level,
                          staffProfile: widget.housekeepingProfile,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF302B2C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Report Damaged", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF302B2C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildQtyBtn(Icons.remove, () {
                if (checklist[label]! > 0) {
                  setState(() => checklist[label] = checklist[label]! - 1);
                }
              }),
              Container(
                width: 50,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "${checklist[label]}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              _buildQtyBtn(Icons.add, () {
                setState(() => checklist[label] = checklist[label]! + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
