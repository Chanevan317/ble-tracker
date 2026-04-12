import 'package:flutter/material.dart';
import 'package:nano_trace_app/services/distance_service.dart';
import '../utils/radar_animation.dart';

class RadarView extends StatelessWidget {
  final Animation<double> animation;
  final bool isConnected;
  final DistanceRange distanceRange;

  const RadarView({
    super.key,
    required this.animation,
    required this.isConnected,
    required this.distanceRange,
  });

  // Logic to calculate the dynamic color based on distance range
  Color _getRadarColor() {
    if (!isConnected) return Colors.grey.shade400; // Grey if disconnected

    switch (distanceRange) {
      case DistanceRange.veryClose:
        return Colors.green; // Bright green
      case DistanceRange.close:
        return Colors.green.shade600; // Darker green
      case DistanceRange.near:
        return Colors.yellow.shade700; // Yellow-orange
      case DistanceRange.far:
        return Colors.orange; // Orange
      case DistanceRange.veryFar:
        return Colors.red; // Red
      case DistanceRange.unknown:
        return Colors.teal; // Teal if searching
    }
  }

  @override
  Widget build(BuildContext context) {
    final radarColor = _getRadarColor();

    return AspectRatio(
      aspectRatio: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: RadialGradient(
            colors: [
              radarColor.withValues(alpha: 0.5),
              radarColor.withValues(alpha: 0.9),
            ],
            center: Alignment.center,
            radius: 0.8,
          ),
        ),
        child: Stack(
          children: [
            if (isConnected && distanceRange != DistanceRange.unknown)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return CustomPaint(painter: RadarPainter(animation.value));
                  },
                ),
              ),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildCenterText(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterText() {
    if (!isConnected) {
      return const Text(
        "The tag is disconnected.\nNo data",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      );
    }

    if (distanceRange == DistanceRange.unknown) {
      return const Text(
        "Searching...",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }

    // Display the distance range label
    return Text(
      distanceRange.label,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
