import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';
import 'package:nano_trace_app/services/ble_service.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/screens/widgets/battery_level.dart';
import 'package:nano_trace_app/screens/widgets/radar_view.dart';
import 'package:nano_trace_app/screens/widgets/status_card.dart';
import 'package:nano_trace_app/services/distance_service.dart';
import 'package:nano_trace_app/services/storage_service.dart';

class TagScreen extends StatefulWidget {
  final TrackerTag tag;
  final VoidCallback onUnpair;

  const TagScreen({super.key, required this.tag, required this.onUnpair});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final KalmanDistanceFilter _kalmanFilter = KalmanDistanceFilter();
  BluetoothDevice? _nearbyDevice;

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _tagNearby = false;
  DistanceRange _range = DistanceRange.unknown;
  Timer? _lostTimer;
  Timer? _systemDeviceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startMonitoring();
  }

  void _startMonitoring() {
    // 1. Check System Devices periodically for bonded tags
    _systemDeviceTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      List<BluetoothDevice> bonded = await FlutterBluePlus.systemDevices([]);
      final foundBonded = bonded.firstWhereOrNull(
        (d) => d.remoteId.str.toLowerCase() == widget.tag.macAddress.toLowerCase()
      );
      
      if (foundBonded != null && !_tagNearby) {
        _onTagFoundManual(foundBonded); 
      }
    });

    // 2. Listen to active scan results
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final ScanResult? myTag = results.firstWhereOrNull((r) {
        // A: Check MAC Address directly
        if (r.device.remoteId.str.toLowerCase() == widget.tag.macAddress.toLowerCase()) {
          return true;
        }

        // B: Check Stealth Signature in Manufacturer Data
        final data = r.advertisementData.manufacturerData[65535];
        if (data != null) {
          final currentSig = String.fromCharCodes(data);
          return currentSig == widget.tag.hardwareName;
        }
        return false;
      });

      if (myTag != null) {
        _handleScanResultFound(myTag);
      }
    });
  }

  void _handleScanResultFound(ScanResult result) {
    _lostTimer?.cancel();
    _lostTimer = Timer(const Duration(seconds: 5), _onTagLost);

    if (DateTime.now().difference(result.timeStamp).inSeconds < 2) {
      if (!_tagNearby) {
        setState(() {
          _tagNearby = true;
          _nearbyDevice = result.device;
        });
        BleService.setNearbyDevice(result.device);
      }
      
      final filtered = _kalmanFilter.filter(result.rssi);
      if (mounted) {
        setState(() => _range = KalmanDistanceFilter.getRange(filtered));
      }
    }
  }

  void _onTagFoundManual(BluetoothDevice device) {
    if (!mounted) return;
    setState(() {
      _tagNearby = true;
      _nearbyDevice = device;
      // We don't have RSSI here, so range stays as is until a scan packet updates it
    });
    BleService.setNearbyDevice(device);
  }

  void _onTagLost() {
    if (!mounted) return;
    _kalmanFilter.reset();
    BleService.setNearbyDevice(null);
    setState(() {
      _tagNearby = false;
      _nearbyDevice = null;
      _range = DistanceRange.unknown;
    });
  }

  @override
  void dispose() {
    _lostTimer?.cancel();
    _systemDeviceTimer?.cancel();
    _scanSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.tag.tagName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        toolbarHeight: 80,
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  RadarView(
                    animation: _controller,
                    isConnected: _tagNearby,
                    distanceRange: _range,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD5D5D5), width: 4),
                            ),
                            child: batteryLevel(0.65), // You can make this dynamic later
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: StatusCard(isConnected: _tagNearby),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: BleService.isBusy
                  ? null
                  : () async {
                      // Create the device object directly from the saved MAC address
                      BluetoothDevice targetDevice = BluetoothDevice.fromId(widget.tag.macAddress);
                      
                      final success = await BleService.triggerBuzzer(targetDevice);
                      
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not reach tag')),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Bip the tag'),
            ),
          ],
        ),
      ),
    );
  }
}