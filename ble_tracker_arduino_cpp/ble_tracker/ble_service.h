#ifndef BLE_SERVICE_H
#define BLE_SERVICE_H
#include <NimBLEDevice.h>

void setupBLE(int pairingType); // 0 = Normal, 1 = Master Pair, 2 = Secondary Pair
bool isPhoneConnected();
void triggerFindMyPhone(); // Function to push the alert to nRF Connect

extern bool _connected; 

#endif