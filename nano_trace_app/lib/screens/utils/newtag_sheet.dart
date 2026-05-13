import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/services/ble_service.dart';
import 'package:nano_trace_app/services/storage_service.dart';

class AddTagSheet {
  static void show(BuildContext context, Function(TrackerTag) onTagAdded) {
    bool isNamingStep = false;
    bool isPairing = false;
    String? discoveredId;
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
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isPairing
                        ? "Linking Tag..."
                        : isNamingStep
                        ? "Name your Tag"
                        : "Searching for Tags...",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Step 1: scanning ──────────────────────────────────
                  if (!isNamingStep && !isPairing) ...[
                    const LinearProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: FutureBuilder<List<TrackerTag>>(
                        future: StorageService.loadTags(),
                        builder: (context, tagsSnapshot) {
                          final pairedTags = tagsSnapshot.data ?? [];

                          return StreamBuilder<List<ScanResult>>(
                            // Pass full tag list for stealth matching
                            stream: BleService.nanoTracerResults(pairedTags),
                            builder: (context, snapshot) {
                              final results = snapshot.data ?? [];

                              // Only show UNPAIRED tags in the add sheet
                              // Unpaired = has name "NanoTrace" or NEW identity bytes
                              final unpaired = results.where((r) {
                                final name = r.advertisementData.advName;
                                if (name.contains("NanoTrace")) return true;
                                final payload = r
                                    .advertisementData
                                    .manufacturerData[0xFFFF];
                                if (payload != null && payload.length >= 3) {
                                  return payload[0] == 0x4E &&
                                      payload[1] == 0x45 &&
                                      payload[2] == 0x57;
                                }
                                return false;
                              }).toList();

                              if (unpaired.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Text(
                                      "Searching for new NanoTrace tags...\n\n"
                                      "Make sure your tag is powered on and nearby.",
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: unpaired.length,
                                itemBuilder: (context, index) {
                                  final result = unpaired[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.bluetooth_searching,
                                      color: Colors.teal,
                                    ),
                                    title: const Text("New NanoTrace Tag"),
                                    subtitle: Text(result.device.remoteId.str),
                                    trailing: Text(
                                      "${result.rssi} dBm",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    onTap: () {
                                      setModalState(() {
                                        discoveredId =
                                            result.device.remoteId.str;
                                        isNamingStep = true;
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ]
                  // ── Step 2: naming ────────────────────────────────────
                  else if (isNamingStep && !isPairing) ...[
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Tag Name (e.g. My Keys)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty || discoveredId == null) return;

                          setModalState(() => isPairing = true);

                          // Pair and get full TrackerTag back
                          final newTag = await BleService.pairTag(
                            remoteId: discoveredId!,
                            tagName: name,
                          );

                          if (newTag != null) {
                            onTagAdded(newTag);
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            setModalState(() => isPairing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Pairing failed. Try again."),
                                ),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Add to My Trackers",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ]
                  // ── Step 3: pairing in progress ───────────────────────
                  else ...[
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 20),
                    const Text("Linking tag to your phone..."),
                    const SizedBox(height: 8),
                    Text(
                      "Do not close this screen",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
