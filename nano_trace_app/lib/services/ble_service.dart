import 'dart:async';

import 'package:collection/collection.dart';
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
      // 1. Pause scan - Essential on Android to free up the radio
      await FlutterBluePlus.stopScan();
      
      // 2. Fast Connect
      // Since no encryption is needed, a 2-3s timeout is plenty
      await device.connect(license: License.free, timeout: const Duration(seconds: 3), autoConnect: false);

      // 3. Short breather for Service Discovery
      // We still need a tiny delay so the GATT table is ready
      await Future.delayed(const Duration(milliseconds: 300));
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? buzzerChar;
      for (var s in services) {
        if (s.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          buzzerChar = s.characteristics.firstWhereOrNull(
            (c) => c.uuid.str128.toLowerCase() == buzzerCharUuid.toLowerCase()
          );
        }
      }

      if (buzzerChar != null) {
        // 4. Fire the command
        // 'withoutResponse: false' is good here to ensure the ESP32 actually got it
        await buzzerChar.write([0x01], timeout: 2);
        debugPrint("[BLE] Bip sent successfully ✓");
        return true;
      }
      return false;

    } catch (e) {
      debugPrint("[BLE] Bip failed: $e");
      return false;
    } finally {
      // 5. Clean up & Resume Scan immediately
      await device.disconnect();
      _isBusy = false;
      
      // Fire the scan restart without 'awaiting' to keep the UI snappy
      FlutterBluePlus.startScan(
        continuousUpdates: true, 
        androidScanMode: AndroidScanMode.lowLatency
      );
    }
  }

  // ── Pairing ───────────────────────
  static Future<String?> pairAndBond(String remoteId) async {
    BluetoothDevice device = BluetoothDevice.fromId(remoteId);
    try {
      await FlutterBluePlus.stopScan(); // Pause scanning during connection
      
      await device.connect(
        license: License.free, 
        timeout: const Duration(seconds: 10),
        autoConnect: false
      );
      
      // REMOVED: await device.createBond(); <-- This was causing the Cache Trap!
      await Future.delayed(const Duration(milliseconds: 500)); 

      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.str128.toLowerCase() == lockCharacteristicUuid.toLowerCase()) {
              
              // 1. Send 0x01 to lock the hardware.
              await char.write([0x01]);
              
              // 2. Give the ESP32 half a second to process and trigger its reboot
              await Future.delayed(const Duration(milliseconds: 500)); 
              await device.disconnect(); 
              
              // 3. CRUCIAL DELAY: Wait for the ESP32 to finish rebooting into Stealth Mode!
              debugPrint("[BLE] Waiting for ESP32 to reboot...");
              await Future.delayed(const Duration(milliseconds: 2500));
              
              // 4. Now start scanning fresh
              FlutterBluePlus.startScan(
                continuousUpdates: true,
                androidScanMode: AndroidScanMode.lowLatency,
              ).catchError((e) => debugPrint("[BLE] Scan restart error: $e"));

              // --- GENERATE THE STEALTH IDENTITY ---
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
      debugPrint("[BLE] Pairing failed: $e");
      return null;
    }
  }

  // ── Unpairing ───────────────────────
  static Future<bool> factoryResetTag(BluetoothDevice device) async {
    if (_isBusy) return false;
    _isBusy = true;

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(
        license: License.free, 
        timeout: const Duration(seconds: 5), 
        autoConnect: false
      );
      await Future.delayed(const Duration(milliseconds: 500));
      
      final services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          final char = s.characteristics.firstWhereOrNull(
            (c) => c.uuid.toString().toLowerCase() == lockCharacteristicUuid.toLowerCase()
          );
          if (char != null) {
            
            // 1. Send Reset Command
            await char.write([0x00]); 
            debugPrint("[BLE] Hardware Reset Command Sent");
            
            // 2. Wait for ESP to trigger reboot
            await Future.delayed(const Duration(milliseconds: 500));
            await device.disconnect();
            
            // 3. CRUCIAL DELAY: Wait for ESP32 to finish rebooting to Visible Mode
            debugPrint("[BLE] Waiting for ESP32 to reboot into Visible mode...");
            await Future.delayed(const Duration(milliseconds: 2500));
            
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint("[BLE] Reset failed: $e");
      return false;
    } finally {
      // Ensure we clean up even if it fails
      if (device.isConnected) {
        await device.disconnect();
      }
      _isBusy = false;
      FlutterBluePlus.startScan(continuousUpdates: true, androidScanMode: AndroidScanMode.lowLatency);
    }
  }
}