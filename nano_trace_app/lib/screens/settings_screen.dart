import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        toolbarHeight: 80,
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'NanoTrace is operating in seamless mode.\nNo account setup required.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}