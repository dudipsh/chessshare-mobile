import 'package:flutter/material.dart';

class ArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  ArrowPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(from, to, paint);

    const arrowSize = 20.0;
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * 1.2 * (to.dx - from.dx).sign,
      to.dy - arrowSize * 0.6,
    );
    path.lineTo(
      to.dx - arrowSize * 1.2 * (to.dx - from.dx).sign,
      to.dy + arrowSize * 0.6,
    );
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
