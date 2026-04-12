#include <Arduino.h>
#include "ble/ble_manager.h"

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("--- NANOTRACE BOOTING ---");
    BLEManager::init();
}

void loop() {
    BLEManager::update();
}