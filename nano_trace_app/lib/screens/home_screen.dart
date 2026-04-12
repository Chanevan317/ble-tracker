import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/screens/widgets/tag_list.dart';
import 'package:nano_trace_app/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nano_trace_app/screens/utils/newtag_sheet.dart';
import 'package:nano_trace_app/screens/settings_screen.dart';
import 'package:nano_trace_app/screens/username_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TrackerTag> myTags = [];

  @override
  void initState() {
    super.initState();
    _initData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureUserCredentials();
    });
  }

  Future<void> _initData() async {
    final loadedTags = await StorageService.loadTags();
    setState(() {
      myTags = loadedTags;
    });
  }

  Future<void> _ensureUserCredentials() async {
    final savedUsername = await StorageService.getSavedUsername();
    final savedUserId = await StorageService.getUserId();

    if ((savedUsername == null || savedUsername.isEmpty) ||
        (savedUserId == null || savedUserId.isEmpty)) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const UsernameSetupScreen()),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestBluetoothPermissions() async {
    // 1. Ask for permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Android requires location for BLE scanning
    ].request();

    // 2. Check if they were granted
    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      // Success! Now show your search sheet
      if (!mounted) return;
      AddTagSheet.show(context, (newTag) async {
        setState(() {
          myTags.add(newTag); // Corrected from tags.add
        });
        // Persist to Shared Preferences
        await StorageService.saveTags(myTags);
      });
    } else {
      // Permissions denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enable Bluetooth permissions in Settings."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),

      // App bar with logo and action buttons
      appBar: AppBar(
        title: Text(
          "NanoTrace",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
        ),
        actions: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => SettingsScreen(),
                    ),
                  );
                },
                icon: Icon(
                  Icons.settings,
                  size: 28,
                  color: Colors.teal.shade900,
                ),
              ),
              SizedBox(width: 10),
            ],
          ),
        ],
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                "My Trackers",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

            myTags.isEmpty
                ? Text(
                    "No paired tags. Add a new tag.",
                    style: TextStyle(fontSize: 16, color: Color(0xFF757575)),
                    textAlign: TextAlign.center,
                  )
                : Expanded(
                    child: TagList(
                      tags: myTags,
                      onRefresh: _initData, // Pass the refresh callback
                    ),
                  ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestBluetoothPermissions,
        icon: Icon(Icons.add),
        label: Text("New Tag"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 8.0, // Custom elevation/shadow
        shape: RoundedRectangleBorder(
          // Custom shape
          borderRadius: BorderRadius.circular(16.0),
        ),
        extendedTextStyle: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
