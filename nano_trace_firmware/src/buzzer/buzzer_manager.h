#pragma once

namespace BuzzerManager {
    void init();
    void update();
    void triggerAlert();
    bool isActive();
    void triggerQuickBip();
}