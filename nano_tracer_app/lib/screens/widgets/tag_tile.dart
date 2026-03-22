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
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    // 1. Grab the global scan results
                    final results = FlutterBluePlus.lastScanResults;
                    
                    // 2. Find the specific result for this tag
                    final myTagResult = results.cast<ScanResult?>().firstWhere(
                      (r) => r?.advertisementData.advName == tag.hardwareName,
                      orElse: () => null,
                    );

                    // 3. Update 'lastSeen' ONLY if the packet is actually new (less than 2s old)
                    if (myTagResult != null) {
                      final packetAge = DateTime.now().difference(myTagResult.timeStamp).inSeconds;
                      if (packetAge < 2) {
                        tag.lastSeen = DateTime.now();
                      }
                    }

                    // 4. Determine connection status based on a 5-second timeout
                    bool isConnected = DateTime.now().difference(tag.lastSeen).inSeconds < 5;

                    return Row(
                      children: [
                        Text(
                          isConnected ? "Connected" : "Disconnected",
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: isConnected ? Colors.greenAccent : Colors.grey[300],
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