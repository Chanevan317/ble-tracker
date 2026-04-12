#include <Arduino.h>
#include "buzzer/buzzer_manager.h"
#include "ble/ble_manager.h"


void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("--- NANOTRACE BOOTING ---");
    BLEManager::init();
}

void loop() {
    BuzzerManager::update();
    BLEManager::update();
}