import 'package:flutter/material.dart'; // This provides the definition for WidgetFlutterBinding!
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase already initialized or error: $e");
  }

  runApp(const GrandRenaiApp());
}

class GrandRenaiApp extends StatelessWidget {
  const GrandRenaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Grand Renai Hotel Inventory',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}
