import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String serviceUuid            = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lockCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String buzzerCharUuid         = "a1b2c3d4-1234-5678-abcd-ef0123456789";

  static bool _isBusy = false;
  static bool get isBusy => _isBusy;

  static BluetoothDevice? _nearbyDevice;
  static BluetoothDevice? get nearbyDevice => _nearbyDevice;
  static void setNearbyDevice(BluetoothDevice? device) {
    _nearbyDevice = device;
  }

  // ── Scan results for pairing screen ──────────────────
  static Stream<List<ScanResult>> nanoTracerResults(List<String> pairedMacs) {
    return FlutterBluePlus.scanResults.map((results) {
      return results.where((r) {
        // 1. If we already paired this MAC, ignore it completely for "New Tag" search
        if (pairedMacs.contains(r.device.remoteId.str)) return false;

        final name = r.advertisementData.advName;
        final mData = r.advertisementData.manufacturerData;

        // 2. Only show it if it looks like an unpaired NanoTrace tag
        if (name.contains("NanoTrace")) return true;
        if (mData.containsKey(65535)) return true;

        return false;
      }).toList();
    });
  }

  // ── Buzzer command ─────────────────────────────────── 
  static Future<bool> triggerBuzzer(BluetoothDevice device) async {
    if (_isBusy) return false;
    _isBusy = true;

    try {
      debugPrint("[BLE] Stopping scan for command...");
      await FlutterBluePlus.stopScan();
      
      // Give the radio a moment to settle
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint("[BLE] Connecting to ${device.remoteId}...");
      await device.connect(license: License.free, timeout: const Duration(seconds: 5), autoConnect: false);

      // CRITICAL: Android needs a delay after connection before discovering services
      if (Platform.isAndroid) {
        await device.clearGattCache(); 
        await Future.delayed(const Duration(milliseconds: 600)); 
      }

      debugPrint("[BLE] Discovering Services...");
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? buzzerChar;

      // Search for the characteristic across all services
      for (var service in services) {
        // Normalize UUIDs to lowercase to avoid "A1B2..." != "a1b2..."
        if (service.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.str128.toLowerCase() == buzzerCharUuid.toLowerCase()) {
              buzzerChar = char;
              break;
            }
          }
        }
      }

      if (buzzerChar != null) {
        debugPrint("[BLE] Characteristic found. Sending 0x01...");
        
        // withoutResponse: false ensures the app waits for an ACK from the ESP32
        await buzzerChar.write([0x01], withoutResponse: false);
        
        debugPrint("[BLE] Command ACK received ✓");
        
        // Keep connection alive for a split second so ESP32 processes the buzz
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      } else {
        debugPrint("[BLE] ERROR: Buzzer characteristic not found in services.");
        return false;
      }

    } catch (e) {
      debugPrint("[BLE] Buzzer Exception: $e");
      return false;
    } finally {
      await device.disconnect();
      debugPrint("[BLE] Disconnected. Restarting scan...");
      
      // Resume global scan
      FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
        timeout: null,
      ).catchError((e) => debugPrint("Scan restart failed: $e"));

      _isBusy = false;
    }
  }

  // ── Pairing (NO USER ID NEEDED) ───────────────────────
  static Future<String?> pairAndBond(String remoteId) async {
    BluetoothDevice device = BluetoothDevice.fromId(remoteId);
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10)
      );
      
      await device.createBond(); 
      debugPrint("[BLE] Bonded successfully");
      await Future.delayed(const Duration(milliseconds: 1000)); 

      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.str128.toLowerCase() == lockCharacteristicUuid.toLowerCase()) {
              
              // Just send 0x01 to lock the hardware. No User ID string needed.
              await char.write([0x01]);
              await Future.delayed(const Duration(seconds: 1)); 

              await device.disconnect(); 
              
              FlutterBluePlus.startScan(
                withServices: [], 
                continuousUpdates: true,
                androidScanMode: AndroidScanMode.lowLatency,
                timeout: const Duration(seconds: 0),
              ).catchError((e) => debugPrint("[BLE] Scan restart error: $e"));

              // --- GENERATE THE STEALTH IDENTITY ---
              // On Android, remoteId is the MAC address (e.g., "8C:FD:49:4B:94:A2")
              // We grab the last 3 bytes to match the firmware's stealth logic.
              List<String> macParts = remoteId.split(':');
              if (macParts.length == 6) {
                int b3 = int.parse(macParts[3], radix: 16);
                int b4 = int.parse(macParts[4], radix: 16);
                int b5 = int.parse(macParts[5], radix: 16);
                return String.fromCharCodes([b3, b4, b5]);
              }
              
              return null;
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("[BLE] Bonding failed: $e");
      return null;
    }
  }

  // ── Internal helpers ──────────────────────────────────
  static Future<bool> _waitForAdvertisement(BluetoothDevice device) async {
    // ... (Keep this exactly as you had it) ...
    final completer = Completer<bool>();
    final timeout = Timer(const Duration(milliseconds: 4000), () {
      if (!completer.isCompleted) completer.complete(false);
    });
    final sub = FlutterBluePlus.scanResults.listen((results) {
      final found = results.any(
        (r) => r.device.remoteId == device.remoteId &&
            DateTime.now().difference(r.timeStamp).inMilliseconds < 500,
      );
      if (found && !completer.isCompleted) completer.complete(true);
    });
    final result = await completer.future;
    await sub.cancel();
    timeout.cancel();
    return result;
  }
}