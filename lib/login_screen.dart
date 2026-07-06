import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'style_constants.dart';
import 'firestore_service.dart';
import 'manager_dashboard.dart';
import 'supervisor_dashboard.dart';
import 'housekeeping_dashboard.dart';
import 'supplier_dashboard.dart';

import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialRole;
  final String? alertMessage;
  final String? initialEmail;

  const LoginScreen({super.key, this.initialRole, this.alertMessage, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String selectedRole;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Automatically match the role passed from the Sign Up screen, or default to Housekeeping
    selectedRole = widget.initialRole ?? 'Housekeeping';
    
    // Autofill email if provided (e.g. from signup confirmation)
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }

    // Trigger the notification popup immediately after the frame builds
    if (widget.alertMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.alertMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            backgroundColor: StyleConstants.formCardBg,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleConstants.appScreenBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.black54, size: 28),
                onPressed: () {},
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('hotel_metadata').doc('logo').snapshots(),
                      builder: (context, snapshot) {
                        String logoBase64 = "";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          logoBase64 = (snapshot.data!.data() as Map<String, dynamic>)['imageUrl'] ?? "";
                        }

                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                            image: logoBase64.isNotEmpty
                                ? DecorationImage(image: MemoryImage(base64Decode(logoBase64)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: logoBase64.isEmpty
                              ? const Icon(Icons.hotel, size: 55, color: StyleConstants.formCardBg)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome to',
                      style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w400),
                    ),
                    const Text(
                      'Grand Renai Hotel Inventory',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, color: StyleConstants.formCardBg, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 25),

                    // THE FLOATING LOGIN PAD CARD
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                      decoration: BoxDecoration(
                        color: StyleConstants.formCardBg,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Log in',
                            style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),

                          _buildLoginTextField('Email', _emailController, 'akmal@grandrenaihotel.com'),
                          _buildLoginTextField(
                            'Password',
                            _passwordController,
                            '******',
                            secure: _obscurePassword,
                            isPasswordField: true,
                            onToggleVisibility: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),

                          const SizedBox(height: 10),
                          const Text(
                            'Acting Profile Role',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),

                          // Dynamic Role Dropdown matching the selected state color schema
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: StyleConstants.inputFieldBg,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedRole,
                                isExpanded: true,
                                dropdownColor: StyleConstants.formCardBg,
                                style: const TextStyle(color: Colors.black, fontSize: 15),
                                items: <String>['Housekeeping', 'Supervisor', 'Supplier', 'Manager'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: TextStyle(color: selectedRole == value ? Colors.black : Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    selectedRole = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 35),

                          Center(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white, width: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 90, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () async {
                                // 1. Extract form text inputs cleanly first
                                String loginEmail = _emailController.text.trim();
                                String loginPassword = _passwordController.text;

                                // 2. Perform immediate empty field validation check
                                if (loginEmail.isEmpty || loginPassword.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter both email and password.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                // 🔐 EMAIL CASING NOTIFICATION CHECK
                                if (loginEmail != loginEmail.toLowerCase()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Incorrect Email Format: Please use only lowercase letters for your email.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                // 3. Show loading circle spinner overlay
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                );

                                try {
                                  // 4. Query Firestore live collections matching this email and password
                                  var verifiedCloudProfile = await FirestoreService().authenticateUserFromCloud(loginEmail, loginPassword);

                                  if (mounted) Navigator.pop(context); // Close loading spinner safely

                                  if (verifiedCloudProfile != null) {
                                    // 0. 🔐 FORCE PASSWORD CHANGE CHECK
                                    if (verifiedCloudProfile['forcePasswordChange'] == true) {
                                      _showForcePasswordChangeDialog(verifiedCloudProfile);
                                      return;
                                    }

                                    // 1. 🔐 ROLE VALIDATION SYNC CHECK
                                    if (verifiedCloudProfile['role'] != selectedRole) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Access Denied: You are registered as a ${verifiedCloudProfile['role']}, '
                                                'but you selected $selectedRole.',
                                          ),
                                          backgroundColor: Colors.amber.shade900,
                                        ),
                                      );
                                      return; // Kills execution completely so they stay on the Login page
                                    }

                                    // 2. SUCCESS ALERT NOTICE
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Access Granted: Welcome back ${verifiedCloudProfile['name']}'),
                                        backgroundColor: Colors.green.shade800,
                                      ),
                                    );

                                    // 3. 🚀 CONDITIONAL ROLE ROUTING
                                    String userRole = verifiedCloudProfile['role'];

                                    if (userRole == 'Manager') {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ManagerDashboard(managerProfile: verifiedCloudProfile),
                                        ),
                                      );
                                    } else if (userRole == 'Housekeeping') {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HousekeepingDashboard(housekeepingProfile: verifiedCloudProfile),
                                        ),
                                      );
                                    } else if (userRole == 'Supervisor') {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SupervisorDashboard(supervisorProfile: verifiedCloudProfile),
                                        ),
                                      );
                                    } else if (userRole == 'Supplier') {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SupplierDashboard(supplierProfile: verifiedCloudProfile),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Role profile system unrecognized.'), backgroundColor: Colors.grey),
                                      );
                                    }
                                  } else {
                                    // FAIL: Credentials don't match anything in the cloud
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Access Denied: Incorrect email or password.'),
                                        backgroundColor: Colors.red.shade900,
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  if (mounted) Navigator.pop(context); // Close spinner on active exceptions
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Database Error: $err'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Text(
                                'Login',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Center(
                            child: TextButton(
                              onPressed: _showForgotPasswordInstructions,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.underline),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                                );
                              },
                              child: const Text(
                                'Create New Account',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Password", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("For security purposes, password resets are handled by hotel management."),
            SizedBox(height: 15),
            Text("Please follow these steps:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("1. Bring your Staff ID Badge to your Supervisor or Manager."),
            Text("2. Ask them to perform a 'Manager Override' reset in their Team Screen."),
            Text("3. They will provide you with a temporary password."),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StyleConstants.formCardBg),
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showForcePasswordChangeDialog(Map<String, dynamic> profile) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 10),
              Text("Set New Password", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Your password was recently reset by a manager. Please set a permanent password to continue.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  prefixIcon: const Icon(Icons.lock_reset),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StyleConstants.formCardBg,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : () async {
                  String newPass = newPasswordController.text;
                  String confirmPass = confirmPasswordController.text;

                  if (newPass.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters.")));
                    return;
                  }
                  if (newPass != confirmPass) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match.")));
                    return;
                  }

                  setDialogState(() => isSaving = true);
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(profile['email']).update({
                      'password': newPass,
                      'forcePasswordChange': false,
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated! Please login with your new password."), backgroundColor: Colors.green));
                      _passwordController.clear(); // Clear the temporary password field
                    }
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Update & Save Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTextField(
    String fieldLabel,
    TextEditingController txtControl,
    String placeholder, {
    bool secure = false,
    bool isPasswordField = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldLabel,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: txtControl,
          obscureText: secure,
          style: const TextStyle(color: Colors.black, fontSize: 15),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            fillColor: StyleConstants.inputFieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            suffixIcon: isPasswordField
                ? IconButton(
                    icon: Icon(
                      secure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black54,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}