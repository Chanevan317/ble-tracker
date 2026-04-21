#include "touch_manager.h"
#include <Arduino.h>
#include "config.h"
#include "../buzzer/buzzer_manager.h"

namespace {
    volatile bool _touchDetected = false;
    unsigned long _lastTouchTime = 0;
    const unsigned long DEBOUNCE_MS = 300; // Prevent double-bips
}

// The Interrupt Service Routine (stored in RAM for speed)
void IRAM_ATTR handleTouchInterrupt() {
    _touchDetected = true;
}

namespace TouchManager {
    void init() {
        // If using an external touch module (TTP223, etc.)
        pinMode(TOUCH_PIN, INPUT_PULLDOWN); 
        attachInterrupt(digitalPinToInterrupt(TOUCH_PIN), handleTouchInterrupt, RISING);
        
        Serial.println("[TOUCH] Interrupts Initialized");
    }

    // Since we want the bip to be instant, we check the flag 
    // inside a very light function called in the main loop
    void processTouch() {
        if (_touchDetected) {
            unsigned long now = millis();
            if (now - _lastTouchTime > DEBOUNCE_MS) {
                // We use BuzzerManager to bip once
                // You might need a new simple method in BuzzerManager 
                // to avoid interfering with the 10s Alert sequence
                BuzzerManager::triggerQuickBip(); 
                
                _lastTouchTime = now;
                Serial.println("[TOUCH] Satisfaction Bip triggered");
            }
            _touchDetected = false;
        }
    }
}