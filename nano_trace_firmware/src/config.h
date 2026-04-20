#pragma once

// Pins
#define BUZZER_PIN    10
#define TOUCH_PIN     4

// Timing for Architecture 1 (320ms interval)
#define ADV_INTERVAL_MS         320   
#define ADV_INTERVAL_UNITS      512   // 320 / 0.625
#define RECONNECT_GRACE_MS      3000

#define TICK_DELAY_ACTIVE_MS    10    // Fast response when busy
#define TICK_DELAY_IDLE_MS      100   // Allow CPU to sleep longer when idle