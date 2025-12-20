import 'package:flutter/material.dart';

import '../../providers/study_board_provider.dart';

class StudyMarkerPainter extends CustomPainter {
  final MarkerType type;

  StudyMarkerPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx, center.dy + 1.5), radius, shadowPaint);

    // Draw main circle
    Color bgColor;
    Color borderColor;

    switch (type) {
      case MarkerType.valid:
        bgColor = const Color(0xFF22C55E);
        borderColor = const Color(0xFF16A34A);
        break;
      case MarkerType.invalid:
        bgColor = const Color(0xFFEF4444);
        borderColor = const Color(0xFFDC2626);
        break;
      case MarkerType.hint:
        bgColor = const Color(0xFFFACC15);
        borderColor = const Color(0xFFEAB308);
        break;
      case MarkerType.none:
        return;
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw symbol
    final symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case MarkerType.valid:
        final path = Path();
        path.moveTo(center.dx - size.width * 0.22, center.dy);
        path.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
        path.lineTo(center.dx + size.width * 0.22, center.dy - size.height * 0.15);
        canvas.drawPath(path, symbolPaint);
        break;
      case MarkerType.invalid:
        final offset = size.width * 0.18;
        canvas.drawLine(
          Offset(center.dx - offset, center.dy - offset),
          Offset(center.dx + offset, center.dy + offset),
          symbolPaint,
        );
        canvas.drawLine(
          Offset(center.dx + offset, center.dy - offset),
          Offset(center.dx - offset, center.dy + offset),
          symbolPaint,
        );
        break;
      case MarkerType.hint:
        final textPainter = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size.width * 0.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
        );
        break;
      case MarkerType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant StudyMarkerPainter oldDelegate) => oldDelegate.type != type;
}
