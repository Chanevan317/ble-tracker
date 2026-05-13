import 'dart:math';
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

  bool _tagNearby = false;
  bool _isMoving = false;
  bool _searchActive = false; // tracks whether search mode is on
  int _battLevel = -1;

  DistanceRange _range = DistanceRange.unknown;

  double _lastAccelMag = 0;
  double _lastGyroMag = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

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
    // Exit search mode when leaving screen
    if (_searchActive) {
      BleService.setSearchMode(widget.tag, false);
    }
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _motionTimer?.cancel();
    _lostTimer?.cancel();
    _scanSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Sensors ────────────────────────────────────────────────────────────────

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

  // ── BLE monitoring ─────────────────────────────────────────────────────────

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
    _lostTimer = Timer(const Duration(seconds: 5), _onTagLost);

    widget.tag.lastSeen = DateTime.now();

    final batt = BleService.getBatteryLevel(result);
    final smoothed = _distanceService.filter(
      result.rssi,
      isPhoneMoving: _isMoving,
    );
    final range = _distanceService.getRange(smoothed);

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

  // ── Search mode toggle ─────────────────────────────────────────────────────

  Future<void> _toggleSearchMode() async {
    if (BleService.isBusy) return;

    final bool enabling = !_searchActive;

    // Optimistic UI update
    setState(() => _searchActive = enabling);

    final success = await BleService.setSearchMode(widget.tag, enabling);

    if (!success && mounted) {
      // Revert if failed
      setState(() => _searchActive = !enabling);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not reach tag')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Radar ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  RadarView(
                    animation: _controller,
                    isConnected: _tagNearby,
                    distanceRange: _range,
                  ),
                  const SizedBox(height: 16),

                  // ── Info cards row ───────────────────────────────────
                  Expanded(
                    child: Row(
                      children: [
                        // Battery card
                        Expanded(
                          flex: 4,
                          child: _InfoCard(
                            child: batteryLevel(
                              _battLevel >= 0 ? _battLevel / 4.0 : 0.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Status card
                        Expanded(
                          flex: 6,
                          child: _InfoCard(
                            child: StatusCard(isConnected: _tagNearby),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search mode card ───────────────────────────────────────
            _SearchModeCard(
              isActive: _searchActive,
              isTagNearby: _tagNearby,
              isBusy: BleService.isBusy,
              onToggle: _toggleSearchMode,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable info card wrapper ─────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Search mode card ───────────────────────────────────────────────────────

class _SearchModeCard extends StatelessWidget {
  final bool isActive;
  final bool isTagNearby;
  final bool isBusy;
  final VoidCallback onToggle;

  const _SearchModeCard({
    required this.isActive,
    required this.isTagNearby,
    required this.isBusy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive ? Colors.teal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.teal.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isActive ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isBusy ? null : onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isActive
                        ? Icons.search_off_rounded
                        : Icons.manage_search_rounded,
                    key: ValueKey(isActive),
                    color: isActive ? Colors.white : Colors.teal,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? "Searching..." : "Search Tag",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isActive
                            ? "Tap to stop — tag advertising at 100ms"
                            : "Fast mode for active finding",
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.white
                        : (isTagNearby ? Colors.teal : Colors.grey[300]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
