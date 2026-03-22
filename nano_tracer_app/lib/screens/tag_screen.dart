import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show ScanResult, FlutterBluePlus;
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

class _TagScreenState extends State<TagScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final KalmanDistanceFilter _kalmanFilter = KalmanDistanceFilter();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Speed of the ripples
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showUnpairConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Unpair Tag?"),
          content: Text("Remove ${widget.tag.tagName} from your trackers?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // 1. Get current list
                List<TrackerTag> currentTags = await StorageService.loadTags();
                // 2. Remove this specific tag
                currentTags.removeWhere((t) => t.id == widget.tag.id);
                // 3. Save back to storage
                await StorageService.saveTags(currentTags);

                if (context.mounted) {
                  widget.onUnpair(); // Refresh Home Screen list
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back home
                }
              },
              child: const Text("Unpair", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),

      appBar: AppBar(
        title: Text(
          widget.tag.tagName,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            elevation: 4,
            icon: Icon(Icons.more_vert, color: Colors.teal.shade900),

            onSelected: (value) {
              if (value == 'unpair') {
                _showUnpairConfirmation(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'unpair',
                  child: Text(
                    'Unpair Tag',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ];
            },
          ),
        ],
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: 32.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];
                  
                  // Find our tag in the scan results
                  final myTag = results.cast<ScanResult?>().firstWhere(
                    (r) => r?.advertisementData.advName == widget.tag.hardwareName,
                    orElse: () => null,
                  );
              
                  bool isConnected = false;
                  double? filteredDistance;
              
                  if (myTag != null) {
                    // 1. Check if the packet is fresh (less than 4s old)
                    final age = DateTime.now().difference(myTag.timeStamp).inSeconds;
                    if (age < 4) {
                      isConnected = true;
                      // Apply the Kalman Filter to the raw RSSI
                      filteredDistance = _kalmanFilter.filter(myTag.rssi);
                    } else {
                      _kalmanFilter.reset(); // Reset if signal is lost for too long
                    }
                  }
              
                  return Column(
                    children: [
                      RadarView(
                        animation: _controller,
                        isConnected: isConnected,
                        distanceInMeters: filteredDistance,
                      ),
                      SizedBox(height: 16),
                      
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Color(0xFFD5D5D5), width: 4),
                                ),
                                child: batteryLevel(0.65),
                              ),
                            ),
                            SizedBox(width: 16.0),
              
                            Expanded(
                              flex: 6,
                              child: StatusCard(isConnected: isConnected),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            SizedBox(height: 16),

            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Bip the tag'),
            ),
          ],
        ),
      ),
    );
  }
}
