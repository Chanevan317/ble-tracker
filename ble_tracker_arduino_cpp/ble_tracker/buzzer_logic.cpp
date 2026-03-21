#include "buzzer_logic.h"

void setupBuzzer() {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
}

void playShortBeep() {
    Serial.println("🔊 BUZZER: [Beep]");
    digitalWrite(BUZZER_PIN, HIGH); delay(100); digitalWrite(BUZZER_PIN, LOW);
}

void playPairingModeStarted() {
    Serial.println("🔊 BUZZER: [Beep]... [Beep]... [BEEEEEEP] (Pairing Mode)");
    // Physical logic goes here later
}

void playFindMyTagAlarm() {
    Serial.println("🔊 BUZZER: 🚨 ALARM RINGING! 🚨 (Find My Tag Triggered)");
    // You can add a loop here later that rings until touched
}