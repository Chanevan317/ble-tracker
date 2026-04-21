import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';
import 'package:nano_trace_app/services/storage_service.dart';
import 'package:nano_trace_app/services/ble_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<TrackerTag> _myTags = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await StorageService.loadTags();
    setState(() => _myTags = tags);
  }

  // --- PERSISTENCE HELPERS ---
  Future<void> _updateTagSettings() async {
    await StorageService.saveTags(_myTags);
  }

  // --- THE UNPAIR SEQUENCE (RESTORED) ---
  Future<void> _unpairSequence(TrackerTag tag) async {
    setState(() => _isProcessing = true);

    // 1. Attempt Hardware Reset (The "Polite" way)
    try {
      await BleService.factoryResetTag(BluetoothDevice.fromId(tag.macAddress))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint("Hardware was unreachable, proceeding with local deletion.");
    }

    // 2. Database Cleanup
    List<TrackerTag> currentTags = await StorageService.loadTags();
    currentTags.removeWhere((t) => t.id == tag.id);
    await StorageService.saveTags(currentTags);

    // 3. UI Refresh
    setState(() {
      _myTags = currentTags;
      _isProcessing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tag.tagName} removed successfully.")),
      );
      if (_myTags.isEmpty) Navigator.pop(context);
    }
  }

  void _confirmUnpair(TrackerTag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Unpair ${tag.tagName}?"),
        content: const Text("This removes the tag from your database. If nearby, it will also be factory reset."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unpairSequence(tag);
            },
            child: const Text("Unpair", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
      ),
      body: _myTags.isEmpty
        ? const Center(child: Text("No tags paired", style: TextStyle(color: Colors.grey)))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInstructionHeader(),
              
              const SizedBox(height: 16),

              ..._myTags.map((tag) => _buildSettingsCard(tag)),
            ],
          ),
    );
  }

  Widget _buildInstructionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                "Configure your Tags",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Adjust how each NanoTrace tag behaves. You can enable alerts to be notified when a tag is left behind, or unpair a tag to reset it.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(TrackerTag tag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.teal.withValues(alpha: 0.04),
          ),
          child: ExpansionTile(
            // 3. This ensures the background stays white when expanded
            collapsedBackgroundColor: Colors.white,
            backgroundColor: Colors.white,
            
            // 4. This removes the 'sharp' border that ExpansionTile adds when open
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(tag.tagName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text(
              tag.macAddress.toUpperCase(), 
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')
            ),
            children: [
              const Divider(height: 1, indent: 20, endIndent: 20),
              
              // Toggle for Alerts
              SwitchListTile(
                title: const Text("Separation Alerts"),
                subtitle: const Text("Notify and vibrate if out of range"),
                value: tag.alertsEnabled,
                activeTrackColor: Colors.teal,
                onChanged: (val) {
                  setState(() => tag.alertsEnabled = val);
                  _updateTagSettings();
                },
              ),
        
              // Alert Repeat Slider
              if (tag.alertsEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Repeat Alert:"),
                      Text("${tag.maxAlertCount}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                ),
                Slider(
                  value: tag.maxAlertCount.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() => tag.maxAlertCount = val.toInt());
                  },
                  onChangeEnd: (val) => _updateTagSettings(),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 24, right: 24, bottom: 16),
                  child: Text("The phone will alert every 20s for the specified count.", 
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              ],
        
              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _isProcessing ? null : () => _confirmUnpair(tag),
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: const Text("Unpair & Reset"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}