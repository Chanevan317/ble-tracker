#include "ble_manager.h"
#include <NimBLEDevice.h>
#include <Preferences.h>
#include "buzzer/buzzer_manager.h"
#include "config.h"
#include <esp_pm.h>

#define SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LOCK_CHAR_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BUZZER_CHAR_UUID "a1b2c3d4-1234-5678-abcd-ef0123456789"

namespace {
    Preferences preferences;
    bool _isPaired        = false;
    bool _isConnected     = false;
    bool _triggerReboot   = false;
    unsigned long _rebootStartTime = 0;
    unsigned long _disconnectedAt = 0;
    uint8_t _btMac[6]; // Hardware-locked BT MAC

    class ServerCallbacks : public NimBLEServerCallbacks {
        void onAuthenticationComplete(NimBLEConnInfo& connInfo) override {
            if (connInfo.isEncrypted()) {
                Serial.println("[BLE] Auth Success: Link Encrypted ✓");
            }
        }

        void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
            _isConnected = true;
            _disconnectedAt = 0;
            Serial.println("[BLE] Client Connected");
        }

        void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
            _isConnected = false;
            _disconnectedAt = millis();
            Serial.printf("[BLE] Disconnected (%d)\n", reason);
            
            NimBLEDevice::getAdvertising()->start();
        }
    };

    class LockCallbacks : public NimBLECharacteristicCallbacks {
        void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
            Serial.println("!!! lock DATA RECEIVED !!!");
            std::string value = pChar->getValue();
            if (value.length() > 0 && value[0] == 0x01) {
                Serial.println("[BLE] Pairing Command Received");
                preferences.putBool("paired", true);
                preferences.end(); 
                _triggerReboot = true;
                _rebootStartTime = millis();
            }
        }
    };

    class BuzzerCallbacks : public NimBLECharacteristicCallbacks {
        void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
            Serial.println("!!! buzzer DATA RECEIVED !!!");
            std::string value = pChar->getValue();
            if (value.length() > 0 && value[0] == 0x01) {
                BuzzerManager::triggerAlert();
            }
        }
    };

    static ServerCallbacks serverCallbacks;
    static LockCallbacks   lockCallbacks;
    static BuzzerCallbacks buzzerCallbacks;
}

namespace BLEManager {
    void init() {
        // Power Management for Light Sleep
        esp_pm_config_esp32c3_t pm_config = {
            .max_freq_mhz = 160, 
            .min_freq_mhz = 10,  
            .light_sleep_enable = true
        };
        esp_pm_configure(&pm_config);

        // Load Pairing State
        preferences.begin("nanotrace", false);
        // preferences.clear(); // Clear stored preferences for testing purposes
        _isPaired = preferences.getBool("paired", false);

        // Get persistent BT MAC
        esp_read_mac(_btMac, ESP_MAC_BT);

        NimBLEDevice::init("");
        NimBLEDevice::setPower(ESP_PWR_LVL_P9);
        NimBLEDevice::setSecurityAuth(true, true, true);
        NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);

        NimBLEServer* pServer = NimBLEDevice::createServer();
        pServer->setCallbacks(&serverCallbacks);
        NimBLEService* pService = pServer->createService(SERVICE_UUID);

        pService->createCharacteristic(LOCK_CHAR_UUID, NIMBLE_PROPERTY::WRITE)->setCallbacks(&lockCallbacks);
        
        // Buzzer requires Bonding/Encryption
        pService->createCharacteristic(
            BUZZER_CHAR_UUID, 
            NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC | NIMBLE_PROPERTY::WRITE_AUTHEN
        )->setCallbacks(&buzzerCallbacks);

        pService->start();

        // --- STEALTH ADVERTISING LOGIC ---
        NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
        
        // Standard "Developer" Company ID
        std::string mData = "\xff\xff"; 

        if (!_isPaired) {
            pAdv->setName("NanoTrace");
            mData += "NEW"; // Discovery hint
        } else {
            pAdv->setName(""); // Invisible to random scans
            // Include the last 3 bytes of the BT MAC as the Stealth Signature
            // These will be: 4B:94:A2 (from your scan)
            mData += (char)_btMac[3];
            mData += (char)_btMac[4];
            mData += (char)_btMac[5];
        }

        pAdv->setManufacturerData(mData);
        
        NimBLEAdvertisementData scanResp;
        scanResp.setCompleteServices(NimBLEUUID(SERVICE_UUID));
        pAdv->setScanResponseData(scanResp);

        pAdv->setAdvertisingInterval(ADV_INTERVAL_UNITS); 
        pAdv->start();

        Serial.printf("[BLE] BT MAC: %02X:%02X:%02X:%02X:%02X:%02X | Status: %s\n", 
                    _btMac[0], _btMac[1], _btMac[2], _btMac[3], _btMac[4], _btMac[5],
                    _isPaired ? "PAIRED (STEALTH)" : "UNPAIRED (VISIBLE)");
    }

    void update() {
        BuzzerManager::update();
        if (_triggerReboot && (millis() - _rebootStartTime >= 1500)) {
            Serial.println("[BLE] Rebooting...");
            ESP.restart();
        }   
    }

    bool isConnected() { return _isConnected; }
    bool recentlyDisconnected() { return _disconnectedAt > 0 && (millis() - _disconnectedAt < RECONNECT_GRACE_MS); }
}