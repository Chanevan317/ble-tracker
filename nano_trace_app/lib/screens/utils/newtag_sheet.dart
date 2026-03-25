import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/services/ble_service.dart'; // Import your model


class AddTagSheet {
  // Changed callback to pass the whole object
  static void show(BuildContext context, Function(TrackerTag) onTagAdded) {
    bool isNamingStep = false;
    bool isPairing = false; // New loading state
    String? discoveredId; // To store the UUID during the transition
    final TextEditingController nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    isPairing ? "Securing Connection..." : (isNamingStep ? "Name your Tag" : "Searching..."),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  if (isPairing) ...[
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 20, width: double.infinity,),
                    const Text("Linking this NanoTracer to your phone..."),
                  ] else if (!isNamingStep) ...[
                    const LinearProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: StreamBuilder<List<ScanResult>>(
                        stream: BleService.nanoTracerResults, // Using the service stream
                        builder: (context, snapshot) {
                          final results = snapshot.data ?? [];

                          if (results.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text("Searching for NanoTracers..."),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final data = results[index];
                              return ListTile(
                                leading: const Icon(Icons.bluetooth_searching, color: Colors.teal),
                                title: Text(data.advertisementData.advName),
                                subtitle: Text(data.device.remoteId.str),
                                onTap: () {
                                  // STEP 1: Just capture the ID and move to Naming
                                  setModalState(() {
                                    discoveredId = data.device.remoteId.str;
                                    isNamingStep = true;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Tag Name",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty && discoveredId != null) {
                            // 1. Show the loading spinner
                            setModalState(() => isPairing = true);

                            // 2. Run the actual Bluetooth Handshake
                            // This returns "NanoTrace-01" or null
                            String? hardwareName = await BleService.pairAndLock(discoveredId!);

                            if (hardwareName != null) {
                              // 3. Create the tag with the User's Nickname AND the Hardware Name
                              final newTag = TrackerTag(
                                id: DateTime.now().millisecondsSinceEpoch.toString(), // Unique Local ID
                                tagName: nameController.text,                         // e.g. "Keys"
                                hardwareName: hardwareName,                           // e.g. "NanoTrace-01"
                                lastSeen: DateTime.now(),
                              );

                              // 4. Pass it back to your Dashboard (main.dart) to be saved
                              onTagAdded(newTag); 
                              
                              if (context.mounted) Navigator.pop(context);
                            } else {
                              // 5. Handle Failure
                              setModalState(() => isPairing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Failed to lock tag. Try again.")),
                                );
                              }
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Add to My Trackers"),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }
}