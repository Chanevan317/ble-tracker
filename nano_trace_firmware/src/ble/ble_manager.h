#pragma once

namespace BLEManager {
    void init();
    void update();
    void shutdown();
    bool isPaired();
    bool isConnected();
    bool recentlyDisconnected();
}