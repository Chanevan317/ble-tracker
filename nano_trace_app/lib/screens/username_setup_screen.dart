import 'package:flutter/material.dart';
import 'package:nano_trace_app/services/storage_service.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorText = 'Please enter a username';
      });
      return;
    }

    setState(() => _saving = true);

    final userId = _generateUserId(username);
    await StorageService.saveUsername(username);
    await StorageService.saveUserId(userId);

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pop(); // Go back to home screen
  }

  String _generateUserId(String username) {
    final normalized = username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+'), '');
    return normalized.isEmpty ? 'user' : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "Setup Username",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to NanoTrace!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please enter your username to get started. A User ID will be generated automatically.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your display name',
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _saving ? null : _saveUsername,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
