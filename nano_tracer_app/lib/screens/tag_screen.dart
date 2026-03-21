import 'dart:math';

import 'package:flutter/material.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),

      appBar: AppBar(
        title: Text(
          "Wallet Tag",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600
          ),
        ),
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green, 
                    borderRadius: BorderRadius.circular(16), 
                  ),
                  child: Stack(
                    children: [
                      // Radial Pattern Layer
                      Positioned.fill(
                        child: CustomPaint(
                          painter: RadarPainter(),
                        ),
                      ),

                      Center(
                        child: Text(
                          "1.5 meters",
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w600,
                            color: Colors.white
                          ),
                        ),
                      ),
                    ] 
                  ),
                ),
              ),
            ),

            FilledButton(
              onPressed: () {

              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal, 
                foregroundColor: Colors.white, 
                textStyle: const TextStyle( 
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                shape: RoundedRectangleBorder( 
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              child: Text('Bip the tag'),
            )
          ],
        ),
      ),
    );
  }
}



class RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, (radius / 4) * i, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}