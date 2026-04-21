import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/screens/widgets/tag_list.dart';
import 'package:nano_trace_app/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nano_trace_app/screens/utils/newtag_sheet.dart';
import 'package:nano_trace_app/screens/settings_screen.dart';

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
    _startGlobalScan();
  }

  Future<void> _startGlobalScan() async {
    // Listen for Bluetooth Adapter changes (On/Off)
    FlutterBluePlus.adapterState.listen((state) async {
      if (state == BluetoothAdapterState.on) {
        final scanGranted = await Permission.bluetoothScan.isGranted;
        final locGranted = await Permission.location.isGranted;

        if (scanGranted && locGranted) {
          await FlutterBluePlus.startScan(
            continuousUpdates: true,
            androidScanMode: AndroidScanMode.lowLatency,
            timeout: null,
          );
          debugPrint("[BLE-APP] Global Scan Active");
        }
      }
    });
  }

  Future<void> _initData() async {
    final loadedTags = await StorageService.loadTags();
    setState(() {
      myTags = loadedTags;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestBluetoothPermissions() async {
    // Check/Request permissions quickly
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, 
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted) {
      // Ensure scan is running if it wasn't
      if (!FlutterBluePlus.isScanningNow) {
        _startGlobalScan();
      }
      
      if (!mounted) return;
      AddTagSheet.show(context, (newTag) async {
        setState(() {
          myTags.add(newTag); 
        });
        await StorageService.saveTags(myTags);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // App bar with logo and action buttons
      appBar: AppBar(
        title: const Text(
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
                    MaterialPageRoute(builder: (context) => const SettingsScreen())
                  ).then((_) => _initData());
                },
                icon: Icon(
                  Icons.settings,
                  size: 24,
                  color: Colors.teal.shade900,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
        toolbarHeight: 80,
        backgroundColor: const Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                "My Trackers",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

            myTags.isEmpty
              ? const Center(child: Text("No paired tags. Add a new tag."))
              : StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  builder: (context, snapshot) {
                    // Every time a new scan result comes in, this block can trigger 
                    // if you want to re-sort or refresh the whole list view.
                    return Expanded(
                      child: TagList(
                        tags: myTags,
                        onRefresh: _initData, 
                      ),
                    );
                  },
                ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestBluetoothPermissions,
        icon: const Icon(Icons.add),
        label: const Text("New Tag"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 8.0, 
        shape: RoundedRectangleBorder(
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