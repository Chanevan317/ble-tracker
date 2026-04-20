import 'dart:convert';
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
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isPairing
                        ? "Securing Connection..."
                        : (isNamingStep ? "Name your Tag" : "Searching..."),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  if (isPairing) ...[
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 20, width: double.infinity),
                    const Text("Linking this NanoTracer to your phone..."),
                  ] else if (!isNamingStep) ...[
                    const LinearProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: FutureBuilder<List<TrackerTag>>(
                        future: StorageService.loadTags(),
                        builder: (context, tagsSnapshot) {
                          final pairedTags = tagsSnapshot.data ?? [];
                          final pairedHardwareNames = pairedTags.map((t) => t.hardwareName).toSet();

                          return StreamBuilder<List<ScanResult>>(
                            stream: BleService.nanoTracerResults(pairedTags.map((t) => t.macAddress).toList()),
                            builder: (context, snapshot) {
                              final results = snapshot.data ?? [];
                              final availableDevices = results.where((r) {
                                // Exclude already paired MACs
                                return !pairedHardwareNames.contains(r.device.remoteId.str);
                              }).toList();

                              if (availableDevices.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Text("Searching for new NanoTracers..."),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableDevices.length,
                                itemBuilder: (context, index) {
                                  final data = availableDevices[index];
                                  return ListTile(
                                    leading: const Icon(Icons.bluetooth_searching, color: Colors.teal),
                                    title: const Text("New NanoTracer"),
                                    subtitle: Text(data.device.remoteId.str),
                                    onTap: () {
                                      setModalState(() {
                                        discoveredId = data.device.remoteId.str;
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
                  ] else ...[
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Tag Name (e.g. My Keys)",
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
                            setModalState(() => isPairing = true);

                            // Pair & get the 3-byte stealth MAC
                            String? hardwareName = await BleService.pairAndBond(discoveredId!);

                            if (hardwareName != null) {
                              final newTag = TrackerTag(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                tagName: nameController.text,
                                hardwareName: hardwareName, // The 3-byte stealth code
                                macAddress: discoveredId!,  // The full 8C:FD... address
                                lastSeen: DateTime.now(),
                              );

                              onTagAdded(newTag);
                              if (context.mounted) Navigator.pop(context);

                            } else {
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
  }
}