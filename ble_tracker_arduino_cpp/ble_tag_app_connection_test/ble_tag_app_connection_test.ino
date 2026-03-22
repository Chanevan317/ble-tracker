#include <NimBLEDevice.h>
#include <Preferences.h>

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LOCK_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

Preferences preferences;
bool isPaired = false;
bool triggerReboot = false;

class MyCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) override {
        std::string value = pCharacteristic->getValue();
        if (value.length() > 0 && value[0] == 0x01) {
            Serial.println("Pairing signal received! Triggering reboot flow...");
            triggerReboot = true;
        }
    }
};

void setup() {
  Serial.begin(115200);
  delay(2000); 
  Serial.println("\n--- NANO TRACER BOOTING ---");
  
  preferences.begin("nanotrace", false);
  // preferences.clear();
  isPaired = preferences.getBool("paired", false);
  
  // FIX: Match these EXACTLY to your Flutter BleService names
  String deviceName = isPaired ? "NanoTrace-01" : "NanoTrace";
  
  Serial.printf("Current Status: %s\n", isPaired ? "LOCKED" : "UNPAIRED");
  Serial.println("Advertising as: " + deviceName);

  NimBLEDevice::init(deviceName.c_str());
  NimBLEServer* pServer = NimBLEDevice::createServer();
  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

  if (!isPaired) {
    NimBLEService* pService = pServer->createService(SERVICE_UUID);
    NimBLECharacteristic* pLockChar = pService->createCharacteristic(
                                        LOCK_CHARACTERISTIC_UUID,
                                        NIMBLE_PROPERTY::WRITE | 
                                        NIMBLE_PROPERTY::WRITE_NR |
                                        NIMBLE_PROPERTY::READ
                                      );

    static MyCallbacks chrCallbacks;
    pLockChar->setCallbacks(&chrCallbacks);
    pService->start();
    pAdvertising->addServiceUUID(SERVICE_UUID);
  } else {
    // In Locked mode, we just provide a heartbeat service
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setAdvertisingInterval(160); 
    pAdvertising->setPreferredParams(0x06, 0x06);
  }

  pAdvertising->enableScanResponse(true);
  pAdvertising->setName(deviceName.c_str()); 
  pAdvertising->start();
}

void loop() {
  if (triggerReboot) {
    // Give Flutter 3 seconds to disconnect gracefully
    delay(3000); 
    Serial.println("Saving pairing status and rebooting...");
    preferences.putBool("paired", true);
    ESP.restart();
  }

  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 10000) {
    Serial.printf("Uptime: %lu s | Mode: %s\n", millis()/1000, isPaired ? "Locked" : "Pairing");
    lastUpdate = millis();
  }
}