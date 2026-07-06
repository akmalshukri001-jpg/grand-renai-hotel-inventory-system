import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'style_constants.dart';
import 'login_screen.dart';
import 'firestore_service.dart';

class SignupConfirmation extends StatefulWidget {
  final String name;
  final String email;
  final String password;
  final String role;

  const SignupConfirmation({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  State<SignupConfirmation> createState() => _SignupConfirmationState();
}

class _SignupConfirmationState extends State<SignupConfirmation> {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verifyAndRegister() async {
    setState(() => _isVerifying = true);

    try {
      // 1. Fetch code from Firestore
      var doc = await FirebaseFirestore.instance
          .collection('register_code')
          .doc(widget.email.toLowerCase())
          .get();

      if (!doc.exists) {
        throw 'No registration request found for this email.';
      }

      String dbCode = doc.data()?['code'] ?? '';
      String? companyName = doc.data()?['companyName'];
      List<String>? categories;
      if (doc.data()?['categories'] != null) {
        categories = List<String>.from(doc.data()!['categories']);
      }

      if (_codeController.text != dbCode) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid confirmation code. Please check again.'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isVerifying = false);
        return;
      }

      // 2. Register User in Cloud
      var cloudProfile = await FirestoreService().registerUserInCloud(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        role: widget.role,
        companyName: companyName,
        categories: categories,
      );

      // 3. Clean up the code from DB (Optional but good practice)
      await FirebaseFirestore.instance
          .collection('register_code')
          .doc(widget.email.toLowerCase())
          .delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              initialRole: cloudProfile['role'],
              initialEmail: widget.email.toLowerCase(),
              alertMessage: 'Successfully Registered!\nYour Cloud Staff ID: ${cloudProfile['staffId']}',
            ),
          ),
          (route) => false,
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration Failure: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleConstants.appScreenBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: StyleConstants.formCardBg,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Verification',
                    style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Please check Grand Renai Hotel Official email or contact Akmal Shukri (Administrator) to receive your 4-digit verification code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'This 4-digit code only valid for 5 minutes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '----',
                      hintStyle: const TextStyle(color: Colors.black26),
                      filled: true,
                      fillColor: StyleConstants.inputFieldBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'To avoid creating unauthorised account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const Text(
                    'Please contact Akmal Shukri (Administrator) for any inquiries (011-3303-1316).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _isVerifying ? null : _verifyAndRegister,
                      child: _isVerifying
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Confirm Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
