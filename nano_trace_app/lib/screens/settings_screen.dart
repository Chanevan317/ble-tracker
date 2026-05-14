import 'package:flutter/material.dart';
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

  // ── Rename ──────────────────────────────────────────────────────────────────

  void _showRenameDialog(TrackerTag tag) {
    final controller = TextEditingController(text: tag.tagName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rename Tag"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Tag name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);

              final idx = _myTags.indexWhere((t) => t.id == tag.id);
              if (idx == -1) return;

              setState(() {
                _myTags[idx] = TrackerTag(
                  id: tag.id,
                  tagName: newName,
                  macAddress: tag.macAddress,
                  token: tag.token,
                  stealthBytes: tag.stealthBytes,
                  lastSeen: tag.lastSeen,
                );
              });
              await StorageService.saveTags(_myTags);

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Renamed to $newName")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ── Unpair ───────────────────────────────────────────────────────────────────

  void _confirmUnpair(TrackerTag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Unpair ${tag.tagName}?"),
        content: const Text(
          "To unpair, the app must connect to the tag and perform a factory reset. "
          "Make sure the tag is nearby and powered on. "
          "If the tag cannot be found, it will not be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _unpairSequence(tag);
            },
            child: const Text("Unpair"),
          ),
        ],
      ),
    );
  }

  Future<void> _unpairSequence(TrackerTag tag) async {
    setState(() => _isProcessing = true);

    bool hardwareReset = false;
    try {
      hardwareReset = await BleService.factoryResetTag(
        tag,
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint("[SETTINGS] Hardware reset failed: $e");
      hardwareReset = false;
    }

    // ONLY remove from storage if the hardware reset was successful
    if (hardwareReset) {
      final current = await StorageService.loadTags();
      current.removeWhere((t) => t.id == tag.id);
      await StorageService.saveTags(current);

      setState(() {
        _myTags = current;
        _isProcessing = false;
      });
    } else {
      // If it failed, just turn off the loading indicator
      setState(() => _isProcessing = false);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hardwareReset
              ? "${tag.tagName} unpaired and reset."
              : "Failed to unpair. Tag not found or connection lost.",
        ),
        backgroundColor: hardwareReset ? null : Colors.redAccent,
      ),
    );

    // Close settings only if successful and no tags left
    if (hardwareReset && _myTags.isEmpty) Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("Resetting tag..."),
                ],
              ),
            )
          : _myTags.isEmpty
          ? const Center(
              child: Text(
                "No tags paired",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                ..._myTags.map((tag) => _buildTagCard(tag)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.teal, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Manage your paired NanoTrace tags.",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(TrackerTag tag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tag name + rename ───────────────────────────────────
            Row(
              children: [
                const Icon(Icons.tag, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tag.tagName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _showRenameDialog(tag),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: "Rename",
                  color: Colors.teal,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              tag.macAddress.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Unpair ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isProcessing ? null : () => _confirmUnpair(tag),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text("Unpair & Reset Tag"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
