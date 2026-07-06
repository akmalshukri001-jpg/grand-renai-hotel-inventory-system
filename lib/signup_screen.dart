import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:convert';
import 'style_constants.dart';
import 'login_screen.dart';
import 'firestore_service.dart';

import 'signup_confirmation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String selectedRole = 'Housekeeping';
  List<String> selectedCategories = [];
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  final List<String> _categories = [
    'Linen & Bedding',
    'Toiletries Supplies',
    'Cleaning Supplies',
    'Housekeeping Equipment',
    'Room Amenities'
  ];

  @override
  Widget build(BuildContext context) {
    bool isSupplier = selectedRole == 'Supplier';

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
                            'Create New Account',
                            style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),

                          _buildWhiteFieldBox(isSupplier ? 'PIC Name' : 'Name', _nameController, isSupplier ? 'Akmal Shukri (Supplier PIC)' : 'Akmal Shukri'),
                          
                          if (isSupplier) ...[
                            _buildWhiteFieldBox('Company Name', _companyNameController, 'Akmal Enterprise'),
                            const Text(
                              'Supplies Categories (Select Multiple)',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _categories.map((String category) {
                                bool isSelected = selectedCategories.contains(category);
                                return FilterChip(
                                  label: Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedCategories.add(category);
                                      } else {
                                        selectedCategories.remove(category);
                                      }
                                    });
                                  },
                                  selectedColor: Colors.black87,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: StyleConstants.inputFieldBg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                          ],

                          _buildWhiteFieldBox('Email', _emailController, 'akmalshukri@gmail.com'),
                          _buildWhiteFieldBox(
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

                          const SizedBox(height: 12),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.8,
                            children: [
                              _buildRoleSelectorTile('Housekeeping'),
                              _buildRoleSelectorTile('Supervisor'),
                              _buildRoleSelectorTile('Supplier'),
                              _buildRoleSelectorTile('Manager'),
                            ],
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
                                String txtName = _nameController.text.trim();
                                String txtEmail = _emailController.text.trim();
                                String txtPassword = _passwordController.text;
                                String txtCompanyName = _companyNameController.text.trim();

                                if (txtName.isEmpty || txtName.contains(RegExp(r'[0-9]'))) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Name cannot be empty and must not contain digits.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (isSupplier && txtCompanyName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Company Name is required for Suppliers.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (isSupplier && selectedCategories.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select at least one supplies category.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (txtEmail.isEmpty || !txtEmail.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid email address with @.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                // 🔐 EMAIL CASING NOTIFICATION CHECK
                                if (txtEmail != txtEmail.toLowerCase()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Warning: Emails must be registered using lowercase letters only.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                if (txtPassword.length < 4) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Password must be at least 4 characters long.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                // 🔐 PREVENT OVERWRITING EXISTING EMAIL DATA
                                try {
                                  // 1. Check if user is already fully registered
                                  var userCheck = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(txtEmail.toLowerCase())
                                      .get();

                                  if (userCheck.exists) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('This email is already registered. Please login.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // 2. Check if a registration code already exists (pending registration)
                                  var codeCheck = await FirebaseFirestore.instance
                                      .collection('register_code')
                                      .doc(txtEmail.toLowerCase())
                                      .get();

                                  if (codeCheck.exists) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('A registration code has already been requested for this email.'),
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                } catch (e) {
                                  debugPrint("Validation error: $e");
                                }

                                String generatedCode = (Random().nextInt(9000) + 1000).toString();
                                
                                try {
                                  Map<String, dynamic> regData = {
                                    'name': txtName,
                                    'email': txtEmail.toLowerCase(),
                                    'role': selectedRole,
                                    'code': generatedCode,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  };

                                  if (isSupplier) {
                                    regData['companyName'] = txtCompanyName;
                                    regData['categories'] = selectedCategories; // Save as list
                                  }

                                  await FirebaseFirestore.instance
                                      .collection('register_code')
                                      .doc(txtEmail.toLowerCase())
                                      .set(regData);

                                  if (mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignupConfirmation(
                                          name: txtName,
                                          email: txtEmail,
                                          password: txtPassword,
                                          role: selectedRole,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Register',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Goes back to LoginScreen which is the root
                              },
                              child: const Text(
                                'Already have an account? Log in',
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

  Widget _buildWhiteFieldBox(
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

  Widget _buildRoleSelectorTile(String roleOptionName) {
    bool isSelected = selectedRole == roleOptionName;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.white.withOpacity(0.25),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.white : Colors.white24, width: 1),
        ),
      ),
      onPressed: () {
        setState(() {
          selectedRole = roleOptionName;
        });
      },
      child: Text(
        roleOptionName,
        style: TextStyle(
          color: isSelected ? StyleConstants.formCardBg : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}