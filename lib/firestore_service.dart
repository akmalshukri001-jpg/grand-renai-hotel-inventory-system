import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FirestoreService {
  // Grab a handling reference pointing directly to your live Cloud Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Automated Staff ID Generation Logic
  /// Extracts structural code prefixes + adds a distinct 4-digit numeric string sequence
  String _generateAutomatedStaffId(String role) {
    String prefix = switch (role) {
      'Manager' => 'MGR',
      'Supervisor' => 'SUP',
      'Supplier' => 'SPL',
      _ => 'HSK', // Defaults to Housekeeping
    };

    int uniqueExtension = Random().nextInt(9000) + 1000;
    return '$prefix-2026-$uniqueExtension';
  }

  /// 📥 CLOUD WRITE: Persists a new account registration map directly to Firestore
  Future<Map<String, dynamic>> registerUserInCloud({
    required String name,
    required String email,
    required String password,
    required String role,
    String? companyName,
    List<String>? categories,
  }) async {
    String staffId = _generateAutomatedStaffId(role);
    String cleanEmail = email.toLowerCase().trim();

    Map<String, dynamic> userDataMatrix = {
      'name': name,
      'email': cleanEmail,
      'password': password, // Note: For production architectures, integrate Firebase Auth to handle hash secrets
      'role': role,
      'staffId': staffId,
      'status': 'Not Available', // 👈 DEFAULT: Set as Not Available on registration
      'createdAt': FieldValue.serverTimestamp(), // Pins precise server clock time
    };

    if (role == 'Supplier') {
      if (companyName != null) userDataMatrix['companyName'] = companyName;
      if (categories != null) userDataMatrix['categories'] = categories;
    }

    // Creates a document named with the user's email inside a collection block called 'users'
    await _db.collection('users').doc(cleanEmail).set(userDataMatrix);

    return userDataMatrix;
  }

  /// 🔍 CLOUD READ: Pulls document map structures down to authenticate credentials
  Future<Map<String, dynamic>?> authenticateUserFromCloud(String email, String password) async {
    String cleanEmail = email.toLowerCase().trim();

    // Attempt to pull document map details matches with this exact text key path identifier
    DocumentSnapshot docSnapshot = await _db.collection('users').doc(cleanEmail).get();

    if (docSnapshot.exists) {
      Map<String, dynamic> firestoreData = docSnapshot.data() as Map<String, dynamic>;

      // Confirm the submitted plaintext password string evaluates correctly against our recorded record
      if (firestoreData['password'] == password) {
        return firestoreData;
      }
    }
    return null; // Signals failure conditions (No document match or incorrect password)
  }

  /// 🔄 CLOUD UPDATE: Updates existing user information in both users and staff_profiles collections
  Future<void> updateUserInCloud({
    required String email,
    required String staffId,
    required Map<String, dynamic> updatedData,
  }) async {
    // 1. Update primary user record
    await _db.collection('users').doc(email.toLowerCase().trim()).update(updatedData);

    // 2. Sync to the 'staff_profiles' collection indexed by staffId
    await _db.collection('staff_profiles').doc(staffId).set(
      {
        ...updatedData,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}