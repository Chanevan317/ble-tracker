import 'dart:math';

import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    for (int i = 0; i < 6; i++) {
      // Use i / 6 so all 6 waves are evenly spaced
      double progress = (animationValue + (i / 3)) % 1.0;

      double currentRadius = maxRadius * progress;
      // Make the opacity a bit stronger so it's visible on the green background
      double opacity = (1.0 - progress) * 0.3;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, currentRadius, paint);
    }
  }
  
  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    // Repaint whenever the animation value changes
    return oldDelegate.animationValue != animationValue;
  }
}