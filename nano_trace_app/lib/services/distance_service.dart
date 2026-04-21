import 'dart:math';

enum DistanceRange {
  veryClose, // 0-1.5m
  close,     // 1.5-3.5m
  near,      // 3.5-7m
  far,       // 7-15m
  veryFar,   // 15m+
  unknown;

  String get label {
    switch (this) {
      case DistanceRange.veryClose:
        return "Right Here";
      case DistanceRange.close:
        return "Close By";
      case DistanceRange.near:
        return "Nearby";
      case DistanceRange.far:
        return "Far Away";
      case DistanceRange.veryFar:
        return "Very Far";
      case DistanceRange.unknown:
        return "Searching...";
    }
  }
}

class KalmanDistanceFilter {
  // --- TUNING PARAMETERS ---
  
  // Process Noise (Q): How fast the distance estimate reacts.
  // Lower = Smoother Radar, but slower to follow you if you run away.
  final double _q = 0.015; 

  // Measurement Noise (R): How much we "distrust" the raw RSSI.
  // BLE RSSI is incredibly noisy. Increasing this prevents "jitter".
  final double _r = 25.0; 

  // --- PHYSICS CONSTANTS (+9 dBm Calibration) ---
  
  // RSSI at 1 meter. 
  static const int measuredPower = -62; 

  // Path Loss Exponent (n). 
  static const double n = 2.4; 

  double _x = 0.0; // Estimated distance
  double _p = 1.0; // Error covariance
  double _k = 0.0; // Kalman gain

  KalmanDistanceFilter() {
    _x = 0.0;
    _p = 1.0;
  }

  double filter(int rssi) {
    // 1. OUTLIER REJECTION (The "Spike Guard")
    // If the RSSI is -100, it's almost always a transient glitch or a hand
    // covering the phone. We cap it to maintain filter stability.
    int sanitizedRssi = rssi.clamp(-95, -30);

    // 2. Convert RSSI to Distance using Log-Distance Path Loss Model
    // Formula: d = 10 ^ ((MeasuredPower - RSSI) / (10 * n))
    double z = pow(10, (measuredPower - sanitizedRssi) / (10 * n)).toDouble();

    // 3. INITIALIZATION
    if (_x == 0.0) {
      _x = z;
      return _x;
    }

    // 4. KALMAN MATH
    _p = _p + _q; // Predict
    _k = _p / (_p + _r); // Gain
    _x = _x + _k * (z - _x); // Update
    _p = (1 - _k) * _p; // Covariance update

    return _x.clamp(0.1, 25.0);
  }

  static DistanceRange getRange(double? distance) {
    if (distance == null || distance <= 0) return DistanceRange.unknown;

    // Adjusted ranges for +9dBm power footprint
    if (distance < 1.5) return DistanceRange.veryClose;
    if (distance < 3.5) return DistanceRange.close;
    if (distance < 7.0) return DistanceRange.near;
    if (distance < 15.0) return DistanceRange.far;
    return DistanceRange.veryFar;
  }

  void reset() {
    _x = 0.0;
    _p = 1.0;
  }
}