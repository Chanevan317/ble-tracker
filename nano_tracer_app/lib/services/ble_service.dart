import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String lockCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Updated to find both Pairing and Locked tags
  static Stream<List<ScanResult>> get nanoTracerResults {
    return FlutterBluePlus.scanResults.map((results) {
      final now = DateTime.now();
      return results.where((r) {
        String name = r.advertisementData.advName;
        // Check for either the pairing name or the locked prefix
        bool isNano = name == "NanoTrace" || name.startsWith("NanoTrace-");
        bool isFresh = now.difference(r.timeStamp).inSeconds < 4;
        return isNano && isFresh;
      }).toList();
    });
  }

  // Returns the Name of the tag if successful, null if failed
  static Future<String?> pairAndLock(String remoteId) async {
    BluetoothDevice device = BluetoothDevice.fromId(remoteId);
    try {
      await device.connect(license: License.free,timeout: const Duration(seconds: 10), autoConnect: false);
      await Future.delayed(const Duration(milliseconds: 500));
      
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == lockCharacteristicUuid) {
              await char.write([0x01]);
              
              // We return the "Locked" version of the name to be saved in Storage
              // In this case, we know it will become "NanoTrace-01"
              await Future.delayed(const Duration(seconds: 1));
              await device.disconnect();
              return "NanoTrace-01"; 
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