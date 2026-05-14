import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';
import 'package:nano_trace_app/services/ble_service.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_normal/normal_mode_layout.dart';
import 'package:nano_trace_app/screens/widgets/tag_screen_search/search_mode_layout.dart';
import 'package:nano_trace_app/services/distance_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TagScreen extends StatefulWidget {
  final TrackerTag tag;
  final VoidCallback onUnpair;

  const TagScreen({super.key, required this.tag, required this.onUnpair});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final DistanceService _distanceService = DistanceService();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  Timer? _lostTimer;
  Timer? _motionTimer;
  Timer? _autoBipCooldown;

  bool _tagNearby = false;
  bool _isMoving = false;
  bool _searchActive = false;
  bool _isBipping = false;
  int _battLevel = -1;

  double _directionAngle = 0.0;
  DistanceRange _range = DistanceRange.unknown;

  double _lastAccelMag = 0;
  double _lastGyroMag = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _initSensors();
    _startMonitoring();
  }

  @override
  void dispose() {
    if (_searchActive) BleService.setSearchMode(widget.tag, false);
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _motionTimer?.cancel();
    _lostTimer?.cancel();
    _autoBipCooldown?.cancel();
    _scanSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _initSensors() {
    _accelSub = userAccelerometerEvents.listen((event) {
      _processInertialData(accel: event);
    });
    _gyroSub = gyroscopeEvents.listen((event) {
      _processInertialData(gyro: event);
    });
  }

  void _processInertialData({
    UserAccelerometerEvent? accel,
    GyroscopeEvent? gyro,
  }) {
    if (accel != null) {
      _lastAccelMag = sqrt(
        accel.x * accel.x + accel.y * accel.y + accel.z * accel.z,
      );
    }
    if (gyro != null) {
      _lastGyroMag = sqrt(gyro.x * gyro.x + gyro.y * gyro.y + gyro.z * gyro.z);
    }
    final bool movingNow = _lastAccelMag > 0.5 || _lastGyroMag > 1.2;
    if (movingNow) {
      _motionTimer?.cancel();
      _motionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isMoving = false);
      });
      if (!_isMoving && mounted) setState(() => _isMoving = true);
    }
  }

  void _startMonitoring() {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final ScanResult? myTag = results.firstWhereOrNull((r) {
        if (r.device.remoteId.str.toLowerCase() ==
            widget.tag.macAddress.toLowerCase())
          return true;
        final payload = r.advertisementData.manufacturerData[0xFFFF];
        if (payload != null && payload.length >= 3) {
          final identity =
              payload[0].toRadixString(16).padLeft(2, '0').toUpperCase() +
              payload[1].toRadixString(16).padLeft(2, '0').toUpperCase() +
              payload[2].toRadixString(16).padLeft(2, '0').toUpperCase();
          if (identity == widget.tag.stealthBytes.toUpperCase()) return true;
        }
        return false;
      });
      if (myTag != null) _handleScanResult(myTag);
    });
  }

  void _handleScanResult(ScanResult result) {
    _lostTimer?.cancel();
    _lostTimer = Timer(const Duration(seconds: 10), _onTagLost);
    widget.tag.lastSeen = DateTime.now();

    final batt = BleService.getBatteryLevel(result);
    final smoothed = _distanceService.filter(
      result.rssi,
      isPhoneMoving: _isMoving,
    );
    final range = _distanceService.getRange(smoothed);

    // Auto-bip when close in search mode
    if (_searchActive &&
        range == DistanceRange.close &&
        !_isBipping &&
        _autoBipCooldown == null) {
      _triggerBip();
    }

    if (mounted) {
      setState(() {
        _tagNearby = true;
        _range = range;
        if (batt != null) _battLevel = batt;
      });
    }
  }

  void _onTagLost() {
    if (!mounted) return;
    _distanceService.reset();
    setState(() {
      _tagNearby = false;
      _range = DistanceRange.unknown;
    });
  }

  Future<void> _toggleSearchMode() async {
    if (BleService.isBusy) return;
    final enabling = !_searchActive;
    setState(() => _searchActive = enabling);
    final success = await BleService.setSearchMode(widget.tag, enabling);
    if (!success && mounted) {
      setState(() => _searchActive = !enabling);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not reach tag')));
    }
  }

  Future<void> _triggerBip() async {
    if (_isBipping || BleService.isBusy) return;
    setState(() => _isBipping = true);
    final success = await BleService.triggerBuzzer(widget.tag);
    if (mounted) setState(() => _isBipping = false);
    _autoBipCooldown = Timer(const Duration(seconds: 10), () {
      _autoBipCooldown = null;
    });
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not reach tag')));
    }
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
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _searchActive
              ? SearchModeLayout(
                  key: const ValueKey('search'),
                  tag: widget.tag,
                  range: _range,
                  tagNearby: _tagNearby,
                  directionAngle: _directionAngle,
                  isBipping: _isBipping,
                  onExitSearch: _toggleSearchMode,
                  onBip: _triggerBip,
                )
              : NormalModeLayout(
                  key: const ValueKey('normal'),
                  controller: _controller,
                  tagNearby: _tagNearby,
                  range: _range,
                  battLevel: _battLevel,
                  isBusy: BleService.isBusy,
                  onToggleSearch: _toggleSearchMode,
                ),
        ),
      ),
    );
  }
}
