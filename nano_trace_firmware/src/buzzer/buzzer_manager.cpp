#include "buzzer_manager.h"
#include <ezBuzzer.h>
#include "config.h"

namespace {
    ezBuzzer buzzer(BUZZER_PIN);
    bool _alertActive = false;
    unsigned long _alertStartTime = 0;
    unsigned long _lastBeepTime = 0;
    const unsigned long ALERT_DURATION_MS = 10000; // 10 seconds total
    const unsigned long BEEP_DURATION_MS  = 300;   // beep length
    const unsigned long BEEP_GAP_MS       = 700;   // silence between beeps
}

namespace BuzzerManager {
    void init() {
        pinMode(BUZZER_PIN, OUTPUT); 
        Serial.println("[BUZZER] Initialized");
    }

    void update() {
        buzzer.loop();

        if (_alertActive) {
        unsigned long now = millis();

        if (now - _alertStartTime >= ALERT_DURATION_MS) {
            _alertActive = false;
            buzzer.stop();
            Serial.println("[BUZZER] Alert stopped");
            return;
        }

        // only beep if buzzer is idle AND enough gap has passed
        if (buzzer.getState() == BUZZER_IDLE &&
            now - _lastBeepTime >= BEEP_GAP_MS) {
            buzzer.beep(BEEP_DURATION_MS);
            _lastBeepTime = now;
        }
        }
    }

    void triggerAlert() {
        _alertActive = true;
        _alertStartTime = millis();
        _lastBeepTime = 0; // force immediate first beep
        Serial.println("[BUZZER] Alert triggered");
    }

    bool isActive() { return _alertActive; }

    void triggerQuickBip() {
        if (!_alertActive) { // Don't interrupt a panic alert
            buzzer.beep(100); // Sharp 100ms bip
        }
    }
}