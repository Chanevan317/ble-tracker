#ifndef TOUCH_SENSOR_H
#define TOUCH_SENSOR_H
#include <Arduino.h>

const int TOUCH_PIN = 2;

struct TouchResult {
    int taps;
    bool isHold;
    bool isLongHold; // Specifically for the 5-second Find My Phone
};

void setupTouch();
TouchResult analyzeTouch();

#endif