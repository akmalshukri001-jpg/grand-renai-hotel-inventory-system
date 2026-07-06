import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class ReportDamagedScreen extends StatefulWidget {
  final int roomNumber;
  final int level;
  final Map<String, dynamic> staffProfile;

  const ReportDamagedScreen({
    super.key,
    required this.roomNumber,
    required this.level,
    required this.staffProfile,
  });

  @override
  State<ReportDamagedScreen> createState() => _ReportDamagedScreenState();
}

class _ReportDamagedScreenState extends State<ReportDamagedScreen> {
  String? selectedCategory;
  final TextEditingController _descriptionController = TextEditingController();
  File? _evidenceImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  final List<String> categories = [
    'Bathroom Equipment',
    'Furniture',
    'Electrical Appliance',
    'Room Amenities',
    'Air Conditioner',
    'Others'
  ];

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _evidenceImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitReport() async {
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a damaged category"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageBase64;
      if (_evidenceImage != null) {
        final bytes = await _evidenceImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      await FirebaseFirestore.instance.collection('damaged_reports').add({
        'roomNumber': widget.roomNumber,
        'level': widget.level,
        'category': selectedCategory,
        'description': _descriptionController.text.trim(),
        'reportedBy': widget.staffProfile['name'],
        'staffId': widget.staffProfile['staffId'],
        'staffEmail': widget.staffProfile['email'],
        'timestamp': FieldValue.serverTimestamp(),
        'photoBase64': imageBase64,
        'status': 'Open',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Damage report submitted successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting report: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Report Damage", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoomHeader(),
            const SizedBox(height: 25),
            const Text("Damage Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCategoryList(),
            const SizedBox(height: 25),
            const Text("Description (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Enter details about the damage...",
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Evidence Photo (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImagePicker(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF302B2C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Report", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.report_problem, color: Colors.red.shade700, size: 40),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Room ${widget.roomNumber}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Level ${widget.level}", style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: categories.map((category) {
          return RadioListTile<String>(
            title: Text(category),
            value: category,
            groupValue: selectedCategory,
            activeColor: Colors.amber.shade800,
            onChanged: (val) => setState(() => selectedCategory = val),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: _evidenceImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_evidenceImage!, fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  Text("Tap to upload photo evidence", style: TextStyle(color: Colors.grey)),
                ],
              ),
      ),
    );
  }
}
