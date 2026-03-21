#include "touch_sensor.h"

void setupTouch() {
    pinMode(TOUCH_PIN, INPUT);
}

TouchResult analyzeTouch() {
    int taps = 0;
    uint32_t timeoutStart = millis();
    
    // Window to wait for the next tap (1.5 seconds)
    while (millis() - timeoutStart < 1500) { 
        if (digitalRead(TOUCH_PIN) == HIGH) {
            uint32_t pressDuration = 0;
            
            // Measure how long the pin stays HIGH
            while (digitalRead(TOUCH_PIN) == LOW) {
                delay(10);
                pressDuration += 10;
                
                // If it's the very first press and held for 5 seconds
                if (taps == 0 && pressDuration >= 5000) {
                    return {0, true, true}; 
                }
                // If it's tapped a few times, then held for 2 seconds
                if (taps > 0 && pressDuration >= 2000) {
                    return {taps, true, false}; 
                }
            }
            
            // If released before hold thresholds, it counts as a tap
            taps++;
            timeoutStart = millis(); // Reset the window for the next tap
            delay(100); // Debounce
        }
    }
    
    // Return the final count if no holds were detected
    return {taps, false, false};
}