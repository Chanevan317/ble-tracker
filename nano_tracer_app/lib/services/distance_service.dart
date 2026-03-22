import 'dart:math';

class KalmanDistanceFilter {
  // Process Noise (Q): How fast the actual distance can change.
  // Lower = smoother but laggier. Higher = faster response to movement.
  double _q = 0.08; 

  // Measurement Noise (R): How much "jitter" is in your RSSI sensor.
  // BLE RSSI is noisy, so 5.0 - 10.0 is a good starting range.
  double _r = 8.0; 

  double _x = 0.0; // Estimated state (Distance)
  double _p = 1.0; // Estimation error covariance
  double _k = 0.0; // Kalman gain

  // Physics constants for the RSSI -> Distance conversion
  static const int measuredPower = -59;
  static const double n = 2.2;

  KalmanDistanceFilter() {
    _x = 0.0;
    _p = 1.0;
  }

  double filter(int rssi) {
    // 1. Convert raw RSSI to raw Distance (The Observation)
    double z = pow(10, (measuredPower - rssi) / (10 * n)).toDouble();

    // 2. Prediction Step
    // We assume the distance stays the same (Static model), 
    // but we increase our uncertainty because time has passed.
    _p = _p + _q;

    // 3. Measurement Update (Correction)
    // Calculate the Kalman Gain: how much do we trust the new measurement vs our prediction?
    _k = _p / (_p + _r);

    // Update the estimate with the new measurement
    _x = _x + _k * (z - _x);

    // Update the error covariance
    _p = (1 - _k) * _p;

    return _x.clamp(0.1, 15.0);
  }

  void reset() {
    _x = 0.0;
    _p = 1.0;
  }
}