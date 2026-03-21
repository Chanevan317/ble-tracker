#include "ble_service.h"
#include "buzzer_logic.h"

bool _connected = false;
NimBLECharacteristic* pFindPhoneChar = nullptr;

// Callback for when the Phone writes to the Tag ("Find My Tag")
class FindTagCallback : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        std::string value = pChar->getValue();
        if (value.length() > 0 && value[0] == '1') {
            Serial.println(">>> BLE COMMAND: Phone is ringing the Tag!");
            playFindMyTagAlarm();
        }
    }
};

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
        _connected = true;
        Serial.println(">>> BLE: Device Connected.");
    }
    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
        _connected = false;
        Serial.println(">>> BLE: Device Disconnected.");
        NimBLEDevice::startAdvertising();
    }
};

void setupBLE(int pairingType) {
    NimBLEDevice::init("C3-Tracker");
    NimBLEServer* pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    NimBLEService* pService = pServer->createService("ABCD");

    // Characteristic 1: Find My Tag (Write from Phone to Tag)
    NimBLECharacteristic* pFindTagChar = pService->createCharacteristic(
        "2222", NIMBLE_PROPERTY::WRITE
    );
    pFindTagChar->setCallbacks(new FindTagCallback());

    // Characteristic 2: Find My Phone (Notify from Tag to Phone)
    pFindPhoneChar = pService->createCharacteristic(
        "3333", NIMBLE_PROPERTY::NOTIFY
    );

    pService->start();

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->setName("C3-Tracker");
    pAdvertising->addServiceUUID(pService->getUUID());
    pAdvertising->enableScanResponse(true);
    pAdvertising->start();
    
    Serial.println(">>> BLE Ready.");
}

void triggerFindMyPhone() {
    if (_connected && pFindPhoneChar != nullptr) {
        Serial.println(">>> BLE: Sending '1' to Phone (Ringing Phone...)");
        pFindPhoneChar->setValue("1");
        pFindPhoneChar->notify();
    } else {
        Serial.println(">>> BLE: Cannot ring phone. No active connection.");
    }
}

// This must be at the bottom of ble_service.cpp
bool isPhoneConnected() {
    return _connected;
}