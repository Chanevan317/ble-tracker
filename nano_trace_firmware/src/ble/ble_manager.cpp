#include "ble_manager.h"
#include <NimBLEDevice.h>
#include <Preferences.h>

#define SERVICE_UUID   "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LOCK_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ── Private state ─────────────────────────────────────────
namespace {
    Preferences preferences;
    bool _isPaired      = false;
    bool _isConnected   = false;
    bool _triggerReboot = false;
    unsigned long _rebootAt = 0;

    class ServerCallbacks : public NimBLEServerCallbacks {
        void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
            _isConnected = true;
            Serial.println("[BLE] Client connected");
        }

        void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
            _isConnected = false;
            Serial.printf("[BLE] Client disconnected, reason: %d\n", reason);

            if (_triggerReboot && millis() >= _rebootAt) {
                preferences.putBool("paired", true);
                ESP.restart();
            }

            // Always restart advertising regardless
            NimBLEDevice::getAdvertising()->start();
            Serial.println("[BLE] Advertising restarted");
        }
    };

    class LockCallbacks : public NimBLECharacteristicCallbacks {
        void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) override {
            std::string value = pCharacteristic->getValue();

            // Expected format: first byte 0x01, rest is userId string
            // e.g: 0x01 + "abc123" → device name becomes "nt-abc123"
            if (value.length() > 1 && value[0] == 0x01) {
                std::string userId = value.substr(1); // extract userId after the 0x01 byte
                std::string deviceName = "nt-" + userId;

                Serial.printf("[BLE] Pairing with userId: %s\n", userId.c_str());
                Serial.printf("[BLE] New device name: %s\n", deviceName.c_str());

                // Save both
                preferences.putBool("paired", true);
                preferences.putString("deviceName", deviceName.c_str());

                _triggerReboot = true;
                _rebootAt = millis() + 3000;
            }
        }
    };

    static ServerCallbacks serverCallbacks;
    static LockCallbacks   lockCallbacks;
}

// ── Public functions ──────────────────────────────────────
namespace BLEManager {

    void init() {
        preferences.begin("nanotrace", false);
        // preferences.clear(); 
        _isPaired = preferences.getBool("paired", false);

        const char* deviceName;
        String savedName;

        if (_isPaired) {
            if (preferences.isKey("deviceName")) {
            savedName = preferences.getString("deviceName", "nt-unknown");
            deviceName = savedName.c_str();
            } else {
            deviceName = "nt-unknown";
            }
        } else {
            deviceName = "NanoTrace";
        }

        Serial.printf("[BLE] Mode: %s | Name: %s\n",
            _isPaired ? "LOCKED" : "UNPAIRED", deviceName);

        // ← exact same order as your original
        NimBLEDevice::init(deviceName);
        NimBLEDevice::setPower(ESP_PWR_LVL_P9);
        NimBLEServer* pServer = NimBLEDevice::createServer();
        pServer->setCallbacks(&serverCallbacks);

        NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

        if (!_isPaired) {
            NimBLEService* pService = pServer->createService(SERVICE_UUID);
            NimBLECharacteristic* pLockChar = pService->createCharacteristic(
            LOCK_CHAR_UUID,
            NIMBLE_PROPERTY::WRITE    |
            NIMBLE_PROPERTY::WRITE_NR |
            NIMBLE_PROPERTY::READ
            );
            pLockChar->setCallbacks(&lockCallbacks);
            pService->start();
            pAdvertising->addServiceUUID(SERVICE_UUID);
        } else {
            pAdvertising->addServiceUUID(SERVICE_UUID);
            pAdvertising->setAdvertisingInterval(160);
            pAdvertising->setPreferredParams(0x06, 0x06);
        }

        pAdvertising->enableScanResponse(true);
        pAdvertising->setName(deviceName);
        pAdvertising->start();

        Serial.println("[BLE] Advertising started");
    }

    void update() {
        if (_triggerReboot && millis() >= _rebootAt) {
        Serial.println("[BLE] Saving pairing and rebooting...");
        preferences.putBool("paired", true);
        ESP.restart();
        }
    }

    bool isPaired()    { return _isPaired;    }
    bool isConnected() { return _isConnected; }
}