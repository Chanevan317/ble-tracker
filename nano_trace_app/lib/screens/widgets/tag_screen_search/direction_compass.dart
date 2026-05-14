import 'dart:math';
import 'package:flutter/material.dart';

class DirectionCompass extends StatelessWidget {
  final double angle;
  final bool tagNearby;

  const DirectionCompass({
    super.key,
    required this.angle,
    required this.tagNearby,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.teal.withValues(alpha: tagNearby ? 0.12 : 0.0),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CustomPaint(
            painter: _CompassPainter(
              angle: angle,
              tagNearby: tagNearby,
              accentColor: Colors.teal,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tagNearby
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    color: tagNearby ? Colors.teal : Colors.grey[400],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tagNearby ? "Estimating" : "Searching",
                    style: TextStyle(
                      fontSize: 12,
                      color: tagNearby ? Colors.teal : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double angle;
  final bool tagNearby;
  final Color accentColor;

  _CompassPainter({
    required this.angle,
    required this.tagNearby,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer track
    final trackPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 4, trackPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final tickAngle = (i / 12) * 2 * pi;
      final isMajor = i % 3 == 0;
      final inner = radius - (isMajor ? 14.0 : 8.0);
      final outer = radius - 4.0;
      canvas.drawLine(
        center +
            Offset(
              cos(tickAngle - pi / 2) * inner,
              sin(tickAngle - pi / 2) * inner,
            ),
        center +
            Offset(
              cos(tickAngle - pi / 2) * outer,
              sin(tickAngle - pi / 2) * outer,
            ),
        tickPaint,
      );
    }

    if (!tagNearby) return;

    // 180° arc
    final arcPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: angle - pi,
        endAngle: angle,
        colors: [
          accentColor.withValues(alpha: 0),
          accentColor.withValues(alpha: 0.25),
          accentColor.withValues(alpha: 0.5),
          accentColor.withValues(alpha: 0.25),
          accentColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      angle - pi,
      pi,
      true,
      arcPaint,
    );

    // Arrow
    final arrowPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arrowLength = radius * 0.55;
    final arrowTip =
        center +
        Offset(
          cos(angle - pi / 2) * arrowLength,
          sin(angle - pi / 2) * arrowLength,
        );
    final arrowBase =
        center +
        Offset(
          cos(angle - pi / 2) * (-arrowLength * 0.2),
          sin(angle - pi / 2) * (-arrowLength * 0.2),
        );

    canvas.drawLine(arrowBase, arrowTip, arrowPaint);

    const arrowHeadAngle = 0.4;
    const arrowHeadLength = 12.0;
    canvas.drawLine(
      arrowTip,
      arrowTip +
          Offset(
            cos(angle - pi / 2 + pi - arrowHeadAngle) * arrowHeadLength,
            sin(angle - pi / 2 + pi - arrowHeadAngle) * arrowHeadLength,
          ),
      arrowPaint,
    );
    canvas.drawLine(
      arrowTip,
      arrowTip +
          Offset(
            cos(angle - pi / 2 + pi + arrowHeadAngle) * arrowHeadLength,
            sin(angle - pi / 2 + pi + arrowHeadAngle) * arrowHeadLength,
          ),
      arrowPaint,
    );

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.angle != angle || old.tagNearby != tagNearby;
}
