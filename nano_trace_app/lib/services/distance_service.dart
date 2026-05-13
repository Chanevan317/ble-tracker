import 'dart:math';

enum DistanceRange {
  close,
  near,
  farAway,
  unknown;

  String get label {
    switch (this) {
      case DistanceRange.close:
        return "Close By";
      case DistanceRange.near:
        return "Nearby";
      case DistanceRange.farAway:
        return "Far Away";
      default:
        return "Searching...";
    }
  }
}

class DistanceService {
  // ── Kalman state ───────────────────────────────────────────────────────────
  static const double _Qslow = 0.1; // slow decay — stationary, small drift
  static const double _Qfast = 3.0; // fast attack — large signal change
  static const double _R = 6.0; // measurement noise variance
  double _x = -70.0;
  double _p = 1.0;

  // ── Median window ──────────────────────────────────────────────────────────
  final List<int> _window = [];
  static const int _windowSize = 3;

  // ── Hysteresis ─────────────────────────────────────────────────────────────
  DistanceRange _currentRange = DistanceRange.unknown;
  static const double _hysteresis = 3.0;

  // ── Debounce ───────────────────────────────────────────────────────────────
  DistanceRange _pendingRange = DistanceRange.unknown;
  int _pendingCount = 0;

  // Debounce counts — asymmetric:
  // moving closer: commit faster (1 sample)
  // moving farther: commit slower (3 samples) to avoid flicker on brief drops
  static const int _debounceCloser = 1;
  static const int _debounceFarther = 3;

  // ── TX power ───────────────────────────────────────────────────────────────
  int _txPowerAtOneMeter = -61;

  // ── Public API ─────────────────────────────────────────────────────────────

  double filter(int rawRssi, {required bool isPhoneMoving}) {
    // 1. Median pre-filter
    _window.add(rawRssi);
    if (_window.length > _windowSize) _window.removeAt(0);

    final double z;
    if (_window.length < _windowSize) {
      z = rawRssi.toDouble();
    } else {
      final sorted = List<int>.from(_window)..sort();
      z = sorted[_windowSize ~/ 2].toDouble();
    }

    // 2. Asymmetric Kalman
    // Large jump toward stronger signal = real movement = respond fast
    // Small change or weakening = could be noise = smooth slowly
    final double delta = z - _x;
    final double absDelta = delta.abs();

    double q;
    if (isPhoneMoving && delta > 0) {
      // Moving + signal improving — maximum responsiveness
      q = _Qfast;
    } else if (absDelta > 8.0) {
      // Large sudden jump in either direction — likely real, respond fast
      q = _Qfast;
    } else if (delta > 3.0) {
      // Moderate improvement — tag getting closer, respond quickly
      q = _Qfast * 0.5;
    } else {
      // Small change or signal drop — smooth it out
      q = _Qslow;
    }

    // When phone moving, increase measurement noise (less trust in reading)
    final double r = isPhoneMoving ? _R * 1.5 : _R;

    _p = _p + q;
    final double k = _p / (_p + r);
    _x = _x + k * (z - _x);
    _p = (1 - k) * _p;

    _updateRange(_x);
    return _x;
  }

  DistanceRange getRange(double smoothedRssi) => _currentRange;

  double estimateDistance(double smoothedRssi) {
    return pow(
      10.0,
      (_txPowerAtOneMeter - smoothedRssi) / (10.0 * 2.7),
    ).toDouble();
  }

  void reset() {
    _x = -70.0;
    _p = 1.0;
    _window.clear();
    _currentRange = DistanceRange.unknown;
    _pendingRange = DistanceRange.unknown;
    _pendingCount = 0;
  }

  void updateTxPower(int txPower) => _txPowerAtOneMeter = txPower;

  // ── Private ────────────────────────────────────────────────────────────────

  void _updateRange(double rssi) {
    const double closeThreshold = -72.0;
    const double nearThreshold = -85.0;

    // Raw range from thresholds
    final DistanceRange raw;
    if (rssi > closeThreshold)
      raw = DistanceRange.close;
    else if (rssi > nearThreshold)
      raw = DistanceRange.near;
    else
      raw = DistanceRange.farAway;

    // Hysteresis
    final DistanceRange candidate = _applyHysteresis(rssi, raw);

    // Asymmetric debounce
    // Determine if this is a "closer" or "farther" transition
    final bool isCloserTransition = _isCloser(candidate, _currentRange);
    final int required = isCloserTransition
        ? _debounceCloser
        : _debounceFarther;

    if (candidate == _pendingRange) {
      _pendingCount++;
      if (_pendingCount >= required) {
        _currentRange = _pendingRange;
      }
    } else {
      _pendingRange = candidate;
      _pendingCount = 1;
    }
  }

  // True if newRange is closer than oldRange
  bool _isCloser(DistanceRange newRange, DistanceRange oldRange) {
    const order = [
      DistanceRange.unknown,
      DistanceRange.farAway,
      DistanceRange.near,
      DistanceRange.close,
    ];
    return order.indexOf(newRange) > order.indexOf(oldRange);
  }

  DistanceRange _applyHysteresis(double rssi, DistanceRange raw) {
    const double closeThreshold = -72.0;
    const double nearThreshold = -85.0;

    switch (_currentRange) {
      case DistanceRange.close:
        if (rssi < closeThreshold - _hysteresis) return DistanceRange.near;
        return DistanceRange.close;

      case DistanceRange.near:
        if (rssi > closeThreshold + _hysteresis) return DistanceRange.close;
        if (rssi < nearThreshold - _hysteresis) return DistanceRange.farAway;
        return DistanceRange.near;

      case DistanceRange.farAway:
        if (rssi > nearThreshold + _hysteresis) return DistanceRange.near;
        return DistanceRange.farAway;

      case DistanceRange.unknown:
        return raw;
    }
  }
}
