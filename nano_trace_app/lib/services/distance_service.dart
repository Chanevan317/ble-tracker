import 'dart:math';

enum DistanceRange {
  veryClose, // 0-1m
  close, // 1-2m
  near, // 2-5m
  far, // 5-10m
  veryFar, // 10m+
  unknown; // no signal

  String get label {
    switch (this) {
      case DistanceRange.veryClose:
        return "Very Close";
      case DistanceRange.close:
        return "Close";
      case DistanceRange.near:
        return "Near";
      case DistanceRange.far:
        return "Far";
      case DistanceRange.veryFar:
        return "Very Far";
      case DistanceRange.unknown:
        return "Unknown";
    }
  }
}

class KalmanDistanceFilter {
  // Process Noise (Q): How fast the actual distance can change.
  final double _q = 0.08;

  // Measurement Noise (R): How much "jitter" is in your RSSI sensor.
  final double _r = 8.0;

  double _x = 0.0; // Estimated state (Distance)
  double _p = 1.0; // Estimation error covariance
  double _k = 0.0; // Kalman gain

  // Physics constants for RSSI -> Distance conversion
  // For ESP32-C3 with ESP_PWR_LVL_P9 (max power ~+9 dBm):
  // Recalibrated measurement power point at 1 meter
  static const int measuredPower = -48; // Adjusted for P9 power level
  static const double n = 2.2; // Path loss exponent

  KalmanDistanceFilter() {
    _x = 0.0;
    _p = 1.0;
  }

  double filter(int rssi) {
    // 1. Convert raw RSSI to raw Distance
    double z = pow(10, (measuredPower - rssi) / (10 * n)).toDouble();

    // 2. Prediction Step
    _p = _p + _q;

    // 3. Measurement Update (Correction)
    _k = _p / (_p + _r);
    _x = _x + _k * (z - _x);
    _p = (1 - _k) * _p;

    return _x.clamp(0.1, 15.0);
  }

  // Convert filtered distance to range category
  static DistanceRange getRange(double? distance) {
    if (distance == null) return DistanceRange.unknown;

    if (distance < 1.0) return DistanceRange.veryClose;
    if (distance < 2.0) return DistanceRange.close;
    if (distance < 5.0) return DistanceRange.near;
    if (distance < 10.0) return DistanceRange.far;
    return DistanceRange.veryFar;
  }

  void reset() {
    _x = 0.0;
    _p = 1.0;
  }
}
