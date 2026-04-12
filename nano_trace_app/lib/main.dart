import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startContinuousScanning();
  }

  Future<void> _startContinuousScanning() async {
    try {
      await FlutterBluePlus.startScan(
        timeout: null, // null means scan until manually stopped
        continuousUpdates: true,
        androidUsesFineLocation: true,
      );
      debugPrint("[BLE-APP] Continuous scanning started");
    } catch (e) {
      debugPrint("[BLE-APP] Scan Error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background
      debugPrint("[BLE-APP] App paused, stopping scan");
      FlutterBluePlus.stopScan();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      debugPrint("[BLE-APP] App resumed, restarting scan");
      _startContinuousScanning();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
