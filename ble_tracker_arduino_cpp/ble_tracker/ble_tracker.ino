#include "ble_service.h"
#include "touch_sensor.h"
#include "buzzer_logic.h"

void setup() {
    Serial.begin(115200);
    setupTouch();
    setupBuzzer();

    int pairingMode = 0; // Default: No pairing
    bool triggerFindPhoneOnBoot = false;

    // Wake up analysis
    esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();
    
    if (cause == ESP_SLEEP_WAKEUP_GPIO || cause == ESP_SLEEP_WAKEUP_EXT0) {
        Serial.println("Touch detected. Analyzing input...");
        playShortBeep(); // Feedback that we woke up
        
        TouchResult res = analyzeTouch();
        
        if (res.isLongHold && res.taps == 0) {
            Serial.println("ACTION: 5-Second Hold -> Find My Phone!");
            triggerFindPhoneOnBoot = true;
        } 
        else if (res.isHold && res.taps == 3) {
            Serial.println("ACTION: 3 Taps + Hold -> Master Pairing Mode!");
            playPairingModeStarted();
            pairingMode = 1;
        }
        else if (res.taps == 5) {
            Serial.println("ACTION: 5 Taps -> Secondary Device Pairing!");
            pairingMode = 2;
        }
        else if (res.isHold && res.taps == 10) {
            Serial.println("ACTION: 10 Taps + Hold -> FACTORY RESET!");
            // clearStorage() goes here
        }
        else {
            Serial.printf("ACTION: Normal Wake. (%d taps recorded)\n", res.taps);
        }
    }

    // Start BLE
    setupBLE(pairingMode);
    
    // If the user held the button to find the phone, send the signal now that BLE is up
    if (triggerFindPhoneOnBoot) {
        // Give the phone a tiny window to reconnect if it was asleep
        delay(1000); 
        triggerFindMyPhone();
    }
}

void loop() {
    if (isPhoneConnected()) {
        delay(1000); // Keep alive
        
        // You can also check for touches while awake here
        if (digitalRead(TOUCH_PIN) == HIGH) {
            TouchResult res = analyzeTouch();
            if (res.isLongHold && res.taps == 0) triggerFindMyPhone();
        }
    } else {
        if (millis() > 60000) {
            esp_deep_sleep_enable_gpio_wakeup(1 << TOUCH_PIN, ESP_GPIO_WAKEUP_GPIO_HIGH);
            esp_deep_sleep_start();
        }
    }
}