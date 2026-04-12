import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lockCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String buzzerCharUuid = "a1b2c3d4-1234-5678-abcd-ef0123456789";

  // persistent connection state
  static BluetoothDevice? _activeDevice;
  static List<BluetoothService> _cachedServices = [];

  static Stream<List<ScanResult>> get nanoTracerResults {
    return FlutterBluePlus.scanResults.map((results) {
      final now = DateTime.now();
      return results.where((r) {
        String name = r.advertisementData.advName;
        bool isNano = name == "NanoTrace" || name.startsWith("nt-");
        bool isFresh = now.difference(r.timeStamp).inSeconds < 4;
        return isNano && isFresh;
      }).toList();
    });
  }

  // call this when tag is found in scan
  static Future<void> connectToDevice(BluetoothDevice device) async {
    if (_activeDevice?.remoteId == device.remoteId) return; // already connected
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      _activeDevice = device;
      _cachedServices = await device.discoverServices();
      debugPrint("[BLE] Connected and services cached");
    } catch (e) {
      debugPrint("[BLE] Connect error: $e");
    }
  }

  static Future<void> disconnectDevice() async {
    await _activeDevice?.disconnect();
    _activeDevice = null;
    _cachedServices = [];
  }

  static Future<void> triggerBuzzer(BluetoothDevice device) async {
    try {
      // Use already-connected device and cached services, don't reconnect
      if (_activeDevice?.remoteId != device.remoteId) {
        debugPrint("[BLE] Device not in active connection");
        return;
      }

      debugPrint("[BLE] Sending buzzer command to connected device...");

      bool sent = false;
      for (var service in _cachedServices) {
        if (service.uuid.toString().toLowerCase().contains(serviceUuid)) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains(buzzerCharUuid)) {
              await char.write([0x01], withoutResponse: false);
              debugPrint("[BLE] Buzzer command sent ✓");
              sent = true;
            }
          }
        }
      }

      if (!sent) {
        debugPrint("[BLE] Buzzer characteristic not found!");
      } else {
        // Keep connection alive during buzzer duration (10 seconds of beeping)
        debugPrint("[BLE] Waiting for buzzer to finish...");
        await Future.delayed(const Duration(milliseconds: 10500));
        debugPrint("[BLE] Buzzer complete, connection ready for next command");
      }
    } catch (e) {
      debugPrint("[BLE] Buzzer error: $e");
    }
    // Keep connection alive - don't disconnect, scan continues
  }

  static Future<String?> pairAndLock(String remoteId, String userId) async {
    BluetoothDevice device = BluetoothDevice.fromId(remoteId);
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(serviceUuid)) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains(
              lockCharacteristicUuid,
            )) {
              final payload = [0x01, ...utf8.encode(userId)];
              await char.write(payload);
              await Future.delayed(const Duration(seconds: 1));
              await device.disconnect();
              return "nt-$userId";
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("Handshake Error: $e");
      return null;
    }
  }
}
