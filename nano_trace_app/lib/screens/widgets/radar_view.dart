import 'package:flutter/material.dart';
import '../utils/radar_animation.dart';

class RadarView extends StatelessWidget {
  final Animation<double> animation;
  final bool isConnected;
  final double? distanceInMeters;

  const RadarView({
    super.key, 
    required this.animation,
    required this.isConnected,
    this.distanceInMeters,
  });

  // 1. Logic to calculate the dynamic color based on distance
  Color _getRadarColor() {
    if (!isConnected) return Colors.grey.shade400; // Grey if disconnected
    if (distanceInMeters == null) return Colors.teal; // Teal if connecting/searching

    // Clamp the distance to a maximum of 10 meters for the color scale
    double normalized = (distanceInMeters! / 10.0).clamp(0.0, 1.0);

    // Smoothly transition (Lerp) from Green (Close) -> Orange (Medium) -> Red (Far)
    if (normalized < 0.5) {
      // 0 to 5 meters
      return Color.lerp(Colors.green, Colors.orange, normalized * 2) ?? Colors.green;
    } else {
      // 5 to 10 meters
      return Color.lerp(Colors.orange, Colors.red, (normalized - 0.5) * 2) ?? Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radarColor = _getRadarColor();

    return AspectRatio(
      aspectRatio: 1.0,
      child: AnimatedContainer(
        // 2. AnimatedContainer ensures the color shifts smoothly as you walk around
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: RadialGradient(
            colors: [
              radarColor.withValues(alpha: 0.5), // Inner gradient
              radarColor.withValues(alpha: 0.9), // Outer gradient
            ],
            center: Alignment.center,
            radius: 0.8,
          ),
        ),
        child: Stack(
          children: [
            // 3. Only draw the radar ripples if the tag is actually connected
            if (isConnected)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RadarPainter(animation.value),
                    );
                  },
                ),
              ),

            // 4. Center text logic
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

    if (distanceInMeters == null) {
      return const Text(
        "Searching...",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }

    // Display the estimated distance (e.g., "≈ 1.5 m")
    return Text(
      "≈ ${distanceInMeters!.toStringAsFixed(1)} m",
      style: const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}