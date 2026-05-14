import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano_trace_app/models/tracker_tag.dart';

class BleService {
  // ── UUIDs — must match firmware exactly ───────────────────────────────────
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lockCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String buzzerCharUuid = "a1b2c3d4-1234-5678-abcd-ef0123456789";
  static const String modeCharUuid = "c0de0001-cafe-babe-dead-beefdeadbeef";

  static bool _isBusy = false;
  static bool get isBusy => _isBusy;

  // ── Token helpers ─────────────────────────────────────────────────────────

  static String generateToken() {
    final rng = Random.secure();
    return List.generate(
      4,
      (_) => rng.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
  }

  static List<int> tokenToBytes(String hex) {
    return List.generate(
      4,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  static String macToStealthBytes(String mac) {
    final p = mac.split(':');
    if (p.length != 6) return '';
    return (p[3] + p[4] + p[5]).toUpperCase();
  }

  // ── UUID comparison ───────────────────────────────────────────────────────

  static bool _uuidMatches(String a, String b) {
    String norm(String u) {
      u = u.toLowerCase().trim();
      if (u.length == 4) u = "0000$u-0000-1000-8000-00805f9b34fb";
      return u;
    }

    return norm(a) == norm(b);
  }

  // ── Scan helpers ──────────────────────────────────────────────────────────

  static Stream<List<ScanResult>> nanoTracerResults(
    List<TrackerTag> pairedTags,
  ) {
    return FlutterBluePlus.scanResults.map((results) {
      // Temporary debug — remove after diagnosis
      for (final r in results) {
        final name = r.advertisementData.advName;
        final mfr = r.advertisementData.manufacturerData;
        if (name.isNotEmpty || mfr.isNotEmpty) {
          debugPrint(
            "[SCAN] device=${r.device.remoteId.str} "
            "name='$name' mfr=${mfr.keys.toList()} "
            "rssi=${r.rssi}",
          );
          mfr.forEach((key, val) {
            debugPrint(
              "[SCAN]   key=$key (0x${key.toRadixString(16)}) "
              "bytes=${val.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').toList()}",
            );
          });
        }
      }

      return results.where((r) {
        final name = r.advertisementData.advName;
        final payload = r.advertisementData.manufacturerData[0xFFFF];

        if (name.contains("NanoTrace")) return true;

        if (payload != null && payload.length >= 3) {
          final b0 = payload[0];
          final b1 = payload[1];
          final b2 = payload[2];

          // Unpaired identity bytes: N=0x4E E=0x45 W=0x57
          if (b0 == 0x4E && b1 == 0x45 && b2 == 0x57) return true;

          final identity =
              b0.toRadixString(16).padLeft(2, '0').toUpperCase() +
              b1.toRadixString(16).padLeft(2, '0').toUpperCase() +
              b2.toRadixString(16).padLeft(2, '0').toUpperCase();

          return pairedTags.any(
            (t) => t.stealthBytes.toUpperCase() == identity,
          );
        }

        return false;
      }).toList();
    });
  }

  static TrackerTag? matchTag(ScanResult result, List<TrackerTag> pairedTags) {
    final payload = result.advertisementData.manufacturerData[0xFFFF];
    if (payload == null || payload.length < 3) return null;

    final identity =
        payload[0].toRadixString(16).padLeft(2, '0').toUpperCase() +
        payload[1].toRadixString(16).padLeft(2, '0').toUpperCase() +
        payload[2].toRadixString(16).padLeft(2, '0').toUpperCase();

    return pairedTags.firstWhereOrNull(
      (t) => t.stealthBytes.toUpperCase() == identity,
    );
  }

  // Read battery level from advertisement — no connection needed
  // Returns 0-4 or null if not available
  static int? getBatteryLevel(ScanResult result) {
    final payload = result.advertisementData.manufacturerData[0xFFFF];
    if (payload == null || payload.length < 6) return null;
    return payload[5]; // byte index 5 = battery level
  }

  // Read search mode flag from advertisement — no connection needed
  // Returns true if tag is currently in search mode
  static bool isInSearchMode(ScanResult result) {
    final payload = result.advertisementData.manufacturerData[0xFFFF];
    if (payload == null || payload.length < 7) return false;
    return (payload[6] & 0x01) != 0; // bit0 of flags byte
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<BluetoothDevice> _connect(
    String remoteId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final device = BluetoothDevice.fromId(remoteId);

    if (device.isConnected) {
      await device.disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await device.connect(
      license: License.free,
      timeout: timeout,
      autoConnect: false,
    );
    debugPrint("[BLE] Connected to $remoteId");

    try {
      await device.clearGattCache();
    } catch (e) {
      debugPrint("[BLE] clearGattCache skipped: $e");
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return device;
  }

  static Future<void> _safeDisconnect(BluetoothDevice? device) async {
    if (device == null) return;
    try {
      if (device.isConnected) await device.disconnect();
    } catch (_) {}
  }

  static Future<void> _resumeScan() async {
    // Wait before restarting — Android throttles if scan starts
    // too quickly after stopping. 1 second is enough to clear
    // the throttle window without noticeable UX impact.
    await Future.delayed(const Duration(milliseconds: 1000));
    try {
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint("[BLE] Scan resume error: $e");
    }
  }

  static Future<BluetoothCharacteristic?> _getChar(
    BluetoothDevice device,
    String charUuid,
  ) async {
    final services = await device.discoverServices();
    for (final s in services) {
      if (_uuidMatches(s.uuid.str128, serviceUuid)) {
        for (final c in s.characteristics) {
          if (_uuidMatches(c.uuid.str128, charUuid)) return c;
        }
      }
    }
    debugPrint("[BLE] Char not found: $charUuid");
    return null;
  }

  // ── Pairing ───────────────────────────────────────────────────────────────

  static Future<TrackerTag?> pairTag({
    required String remoteId,
    required String tagName,
  }) async {
    if (_isBusy) _isBusy = false; // safety reset if stuck
    _isBusy = true;

    BluetoothDevice? device;
    bool wrote = false;

    try {
      final token = generateToken();
      final bytes = tokenToBytes(token);
      final stealthBytes = macToStealthBytes(remoteId);

      debugPrint("[PAIR] remoteId=$remoteId token=$token");

      device = await _connect(remoteId, timeout: const Duration(seconds: 10));

      final lockChar = await _getChar(device, lockCharUuid);
      if (lockChar == null) {
        debugPrint("[PAIR] Lock char not found");
        return null;
      }

      await lockChar.write([0x01, ...bytes], withoutResponse: false);
      debugPrint("[PAIR] Claimed ✓");
      wrote = true;

      await Future.delayed(const Duration(milliseconds: 800));
      await _safeDisconnect(device);

      // Wait for firmware reboot into stealth mode
      await Future.delayed(const Duration(milliseconds: 3000));

      return TrackerTag(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tagName: tagName,
        macAddress: remoteId,
        token: token,
        stealthBytes: stealthBytes,
        lastSeen: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint("[PAIR] Failed: $e\n$stack");
      return null;
    } finally {
      if (!wrote) await _safeDisconnect(device);
      _isBusy = false;
      await _resumeScan();
    }
  }

  // ── Factory reset ─────────────────────────────────────────────────────────

  static Future<bool> factoryResetTag(TrackerTag tag) async {
    if (_isBusy) return false;
    _isBusy = true;

    BluetoothDevice? device;
    try {
      device = await _connect(tag.macAddress);

      final lockChar = await _getChar(device, lockCharUuid);
      if (lockChar == null) return false;

      await lockChar.write([
        0x00,
        ...tokenToBytes(tag.token),
      ], withoutResponse: false);
      debugPrint("[RESET] Released ✓");

      await Future.delayed(const Duration(milliseconds: 800));
      await _safeDisconnect(device);
      await Future.delayed(const Duration(milliseconds: 3000));
      return true;
    } catch (e) {
      debugPrint("[RESET] Failed: $e");
      return false;
    } finally {
      await _safeDisconnect(device);
      _isBusy = false;
      await _resumeScan();
    }
  }

  // ── Buzzer ────────────────────────────────────────────────────────────────

  static Future<bool> triggerBuzzer(TrackerTag tag) async {
    if (_isBusy) return false;
    _isBusy = true;

    BluetoothDevice? device;
    try {
      device = await _connect(
        tag.macAddress,
        timeout: const Duration(seconds: 5),
      );

      final buzzer = await _getChar(device, buzzerCharUuid);
      if (buzzer == null) return false;

      await buzzer.write([
        ...tokenToBytes(tag.token),
        0x01,
      ], withoutResponse: false);
      debugPrint("[BUZZ] Triggered ✓");
      return true;
    } catch (e) {
      debugPrint("[BUZZ] Failed: $e");
      return false;
    } finally {
      await _safeDisconnect(device);
      _isBusy = false;
      await _resumeScan();
    }
  }

  // ── Search mode ───────────────────────────────────────────────────────────
  // Sends mode command then immediately disconnects.
  // Tag switches advertising interval and TX power autonomously.
  // Internal 5-min safety timer on firmware reverts if app dies.

  static Future<bool> setSearchMode(TrackerTag tag, bool enable) async {
    if (_isBusy) return false;
    _isBusy = true;

    BluetoothDevice? device;
    try {
      device = await _connect(
        tag.macAddress,
        timeout: const Duration(seconds: 5),
      );

      final modeChar = await _getChar(device, modeCharUuid);
      if (modeChar == null) return false;

      await modeChar.write([
        ...tokenToBytes(tag.token),
        enable ? 0x01 : 0x00,
      ], withoutResponse: false);
      debugPrint("[MODE] Search mode ${enable ? 'ON' : 'OFF'} ✓");
      return true;
    } catch (e) {
      debugPrint("[MODE] Failed: $e");
      return false;
    } finally {
      // Always disconnect — tag advertises unconnected in search mode
      await _safeDisconnect(device);
      _isBusy = false;
      await _resumeScan();
    }
  }
}
