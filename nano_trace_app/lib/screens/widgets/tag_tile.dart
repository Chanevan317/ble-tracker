import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/tracker_tag.dart';
import '../tag_screen.dart';

class TagTile extends StatelessWidget {
  final TrackerTag tag;
  final VoidCallback onRefresh;

  const TagTile({
    super.key,
    required this.tag,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TagScreen(tag: tag, onUnpair: onRefresh),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tag.tagName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                
                StreamBuilder(
                  // Tick every 2 seconds to force a UI refresh even if no new BLE packets arrive
                  stream: Stream.periodic(const Duration(seconds: 2)),
                  builder: (context, snapshot) {
                    bool isNearby = false;

                    // 1. Get the sticky list of all seen devices
                    final results = FlutterBluePlus.lastScanResults;
                    
                    // 2. Find THIS specific tag in the list
                    final myTagResult = results.firstWhereOrNull((r) {
                      bool macMatch = r.device.remoteId.str.toLowerCase() == tag.macAddress.toLowerCase();
                      
                      // Fallback check for the stealth manufacturer data signature
                      final data = r.advertisementData.manufacturerData[65535];
                      bool sigMatch = data != null && String.fromCharCodes(data) == tag.hardwareName;
                      
                      return macMatch || sigMatch;
                    });

                    // 3. Verify Freshness
                    if (myTagResult != null) {
                      final packetAge = DateTime.now().difference(myTagResult.timeStamp).inSeconds;
                      
                      // If the packet is older than 10 seconds, it's a "ghost" from the buffer
                      if (packetAge < 5) {
                        isNearby = true;
                        // Optionally update the tag's internal lastSeen for persistence
                        tag.lastSeen = myTagResult.timeStamp;
                      }
                    }

                    // 4. Final fallback check against the persistent lastSeen timestamp
                    // This helps if the scan results were cleared but we know we saw it recently
                    if (!isNearby) {
                      isNearby = DateTime.now().difference(tag.lastSeen).inSeconds < 5;
                    }

                    return Row(
                      children: [
                        Text(
                          isNearby ? "Nearby" : "Out of Range",
                          style: TextStyle(
                            color: isNearby ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: isNearby ? Colors.greenAccent : Colors.grey[300],
                        ),
                      ],
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}