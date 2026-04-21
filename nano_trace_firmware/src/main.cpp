#include <Arduino.h>
#include <esp_sleep.h>
#include "config.h"
#include "ble/ble_manager.h"
#include "buzzer/buzzer_manager.h"
#include "touch/touch_manager.h"

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("--- NANOTRACE BOOTING ---");
    BuzzerManager::init();
    TouchManager::init();
    BLEManager::init();
}

void loop() {
    TouchManager::processTouch();
    BLEManager::update();

    // If we are connected or beeping, stay awake.
    // If not, vTaskDelay allows the FreeRTOS IDLE task to run, 
    // which triggers the Light Sleep we configured in BLEManager::init.
    bool busy = BLEManager::isConnected() 
                || BLEManager::recentlyDisconnected() 
                || BuzzerManager::isActive();

    if (busy) {
        vTaskDelay(pdMS_TO_TICKS(TICK_DELAY_ACTIVE_MS)); 
    } else {
        // 100ms delay is safe for a 320ms advertising interval.
        // It gives the CPU plenty of time to sleep between pulses.
        vTaskDelay(pdMS_TO_TICKS(TICK_DELAY_IDLE_MS));
    }
}