import 'package:flutter/material.dart';
import 'package:nano_trace_app/services/distance_service.dart';

class DistanceIndicator extends StatelessWidget {
  final DistanceRange range;
  final bool tagNearby;

  const DistanceIndicator({
    super.key,
    required this.range,
    required this.tagNearby,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          _DistanceStep(
            label: "Close",
            icon: Icons.sensors_rounded,
            active: tagNearby && range == DistanceRange.close,
            color: Colors.teal,
          ),
          _DistanceDivider(active: tagNearby && range == DistanceRange.close),
          _DistanceStep(
            label: "Near",
            icon: Icons.wifi_rounded,
            active: tagNearby && range == DistanceRange.near,
            color: Colors.orange,
          ),
          _DistanceDivider(active: tagNearby && range == DistanceRange.near),
          _DistanceStep(
            label: "Far",
            icon: Icons.signal_wifi_statusbar_null_rounded,
            active: tagNearby && range == DistanceRange.farAway,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _DistanceStep extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;

  const _DistanceStep({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: active ? color : Colors.grey[300],
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? color : Colors.grey[400],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceDivider extends StatelessWidget {
  final bool active;
  const _DistanceDivider({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 1.5,
      color: active ? Colors.teal.withValues(alpha: 0.3) : Colors.grey[200],
    );
  }
}
