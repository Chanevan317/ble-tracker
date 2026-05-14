import 'package:flutter/material.dart';

Widget batteryLevel(double batteryLevel) {
  // batteryLevel from 0.0 to 1.0 (0% to 100%)
  int filledSegments;
  Color activeColor;

  // 1. Define the Thresholds
  if (batteryLevel >= 0.75) {
    filledSegments = 4;
    activeColor = const Color(0xFF4CAF50);
  } else if (batteryLevel >= 0.50) {
    filledSegments = 3;
    activeColor = const Color(0xFFCDDC39);
  } else if (batteryLevel >= 0.25) {
    filledSegments = 2;
    activeColor = const Color(0xFFFF9800);
  } else if (batteryLevel > 0.05) {
    filledSegments = 1;
    activeColor = const Color(0xFFF44336);
  } else {
    filledSegments = 0; // Battery is effectively dead
    activeColor = Colors.transparent;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
    child: Column(
      children: List.generate(4, (index) {
        // Bottom-to-top filling logic
        bool isFilled = (3 - index) < filledSegments;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              color: isFilled ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    ),
  );
}