import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../models/tracker_tag.dart';
import '../../tag_screen.dart';

class TagTile extends StatefulWidget {
  final TrackerTag tag;
  final VoidCallback onRefresh;

  const TagTile({super.key, required this.tag, required this.onRefresh});

  @override
  State<TagTile> createState() => _TagTileState();
}

class _TagTileState extends State<TagTile> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _lostTimer;
  bool _isNearby = false;
  int _rssi = -100;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _lostTimer?.cancel();
    super.dispose();
  }

  void _startListening() {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (_matchesTag(r)) {
          _onFound(r.rssi);
          return;
        }
      }
    });
  }

  bool _matchesTag(ScanResult r) {
    // A: MAC match
    if (r.device.remoteId.str.toLowerCase() ==
        widget.tag.macAddress.toLowerCase())
      return true;

    // B: Stealth identity bytes
    final payload = r.advertisementData.manufacturerData[0xFFFF];
    if (payload != null && payload.length >= 3) {
      final identity =
          payload[0].toRadixString(16).padLeft(2, '0').toUpperCase() +
          payload[1].toRadixString(16).padLeft(2, '0').toUpperCase() +
          payload[2].toRadixString(16).padLeft(2, '0').toUpperCase();
      if (identity == widget.tag.stealthBytes.toUpperCase()) return true;
    }

    return false;
  }

  void _onFound(int rssi) {
    _lostTimer?.cancel();
    _lostTimer = Timer(const Duration(seconds: 10), _onLost);

    if (mounted) {
      setState(() {
        _isNearby = true;
        _rssi = rssi;
      });
    }
  }

  void _onLost() {
    if (mounted) {
      setState(() {
        _isNearby = false;
        _rssi = -100;
      });
    }
  }

  // Convert RSSI to a 0-3 signal bar count
  int get _signalBars {
    if (_rssi >= -70) return 3;
    if (_rssi >= -85) return 2;
    if (_rssi >= -95) return 1;
    return 0;
  }

  String get _statusLabel {
    if (!_isNearby) return "Away";
    if (_rssi >= -70) return "Close By";
    if (_rssi >= -85) return "Nearby";
    return "Far Away";
  }

  Color get _statusColor {
    if (!_isNearby) return Colors.grey;
    if (_rssi >= -70) return Colors.green;
    if (_rssi >= -85) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TagScreen(tag: widget.tag, onUnpair: widget.onRefresh),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // ── Tag icon ───────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: _statusColor,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                // ── Tag name + status label ────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tag.tagName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Signal bars ────────────────────────────────────────
                if (_isNearby)
                  _SignalBars(bars: _signalBars, color: _statusColor)
                else
                  Icon(
                    Icons.signal_wifi_off_outlined,
                    color: Colors.grey[300],
                    size: 22,
                  ),

                const SizedBox(width: 4),

                // ── Chevron ────────────────────────────────────────────
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Signal bar widget ──────────────────────────────────────────────────────

class _SignalBars extends StatelessWidget {
  final int bars; // 0-3
  final Color color;

  const _SignalBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final active = i < bars;
        final height = 8.0 + (i * 5.0); // 8, 13, 18
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 5,
            height: height,
            decoration: BoxDecoration(
              color: active ? color : Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
