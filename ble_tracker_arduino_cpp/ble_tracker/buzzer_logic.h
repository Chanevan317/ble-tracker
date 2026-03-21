#ifndef BUZZER_LOGIC_H
#define BUZZER_LOGIC_H
#include <Arduino.h>

const int BUZZER_PIN = 10; 

void setupBuzzer();
void playShortBeep();
void playPairingModeStarted();
void playFindMyTagAlarm();

#endif