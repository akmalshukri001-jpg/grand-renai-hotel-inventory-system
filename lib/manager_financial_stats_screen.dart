import 'package:flutter/material.dart';

class ManagerFinancialStatsScreen extends StatelessWidget {
  const ManagerFinancialStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Financial Analysis"),
        backgroundColor: const Color(0xFFC98A6B),
      ),
      body: const Center(
        child: Text("Detailed Financial Statistics coming soon!"),
      ),
    );
  }
}
