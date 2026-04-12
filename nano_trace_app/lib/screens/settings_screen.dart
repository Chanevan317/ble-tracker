import 'package:flutter/material.dart';
import 'package:nano_trace_app/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final username = await StorageService.getUsername();
    final userId = await StorageService.getUserId();

    if (!mounted) return;
    setState(() {
      _usernameController.text = username == "Guest User" ? "" : username;
      _userIdController.text = userId ?? "";
    });
  }

  Future<void> _saveUserPreferences() async {
    setState(() => _saving = true);
    await StorageService.saveUsername(_usernameController.text.trim());
    await StorageService.saveUserId(_userIdController.text.trim());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username and User ID saved.')),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),

      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              TextField(
                controller: _usernameController,
                readOnly: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your display name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _userIdController,
                readOnly: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  hintText: 'Enter your user id',
                  helperText: 'This ID is used when pairing a NanoTracer.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: () => setState(() => _isEditing = true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Modify User Info'),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveUserPreferences,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Save User Info'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              Text(
                'Once saved, the app uses this username and user id for pairing and tagging.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
