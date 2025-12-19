import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/move_classification.dart';

/// Chess.com-style move classification markers
class MoveMarker extends StatelessWidget {
  final MoveClassification classification;
  final double size;

  const MoveMarker({
    super.key,
    required this.classification,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (classification == MoveClassification.none) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(size, size),
      painter: _MarkerPainter(classification),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final MoveClassification classification;

  _MarkerPainter(this.classification);

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
    final bgPaint = Paint()..color = _getBackgroundColor();
    canvas.drawCircle(center, radius, bgPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = _getBorderColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw symbol
    _drawSymbol(canvas, size);
  }

  Color _getBackgroundColor() {
    switch (classification) {
      case MoveClassification.book:
        return const Color(0xFFCDA06F);
      case MoveClassification.brilliant:
        return const Color(0xFF109888);
      case MoveClassification.great:
        return const Color(0xFF4784BE);
      case MoveClassification.best:
        return const Color(0xFF79B84A);
      case MoveClassification.good:
        return const Color(0xFF5D9948);
      case MoveClassification.inaccuracy:
        return const Color(0xFFF59E0B);
      case MoveClassification.mistake:
        return const Color(0xFFDD7C2C);
      case MoveClassification.miss:
        return const Color(0xFFFF7769);
      case MoveClassification.blunder:
        return const Color(0xFFFA412D);
      case MoveClassification.forced:
        return const Color(0xFF6B7280);
      case MoveClassification.none:
        return Colors.transparent;
    }
  }

  Color _getBorderColor() {
    switch (classification) {
      case MoveClassification.book:
        return const Color(0xFF8B6914);
      case MoveClassification.brilliant:
        return const Color(0xFF0D7A6E);
      case MoveClassification.great:
        return const Color(0xFF5A7A9A);
      case MoveClassification.best:
        return const Color(0xFF5D8B38);
      case MoveClassification.good:
        return const Color(0xFF4A7C3A);
      case MoveClassification.inaccuracy:
        return const Color(0xFFD97706);
      case MoveClassification.mistake:
        return const Color(0xFFB8661F);
      case MoveClassification.miss:
        return const Color(0xFFE65A4D);
      case MoveClassification.blunder:
        return const Color(0xFFD63525);
      case MoveClassification.forced:
        return const Color(0xFF4B5563);
      case MoveClassification.none:
        return Colors.transparent;
    }
  }

  void _drawSymbol(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (classification) {
      case MoveClassification.book:
        _drawBook(canvas, center, size.width);
        break;
      case MoveClassification.brilliant:
        _drawText(canvas, center, size.width, '!!');
        break;
      case MoveClassification.great:
        _drawText(canvas, center, size.width, '!');
        break;
      case MoveClassification.best:
        _drawStar(canvas, center, size.width);
        break;
      case MoveClassification.good:
        _drawCheckmark(canvas, center, size.width);
        break;
      case MoveClassification.inaccuracy:
        _drawText(canvas, center, size.width, '?!');
        break;
      case MoveClassification.mistake:
        _drawText(canvas, center, size.width, '?');
        break;
      case MoveClassification.miss:
        _drawX(canvas, center, size.width);
        break;
      case MoveClassification.blunder:
        _drawText(canvas, center, size.width, '??');
        break;
      case MoveClassification.forced:
        _drawArrow(canvas, center, size.width);
        break;
      case MoveClassification.none:
        break;
    }
  }

  void _drawText(Canvas canvas, Offset center, double width, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: width * (text.length > 1 ? 0.45 : 0.55),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawCheckmark(Canvas canvas, Offset center, double width) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(center.dx - width * 0.22, center.dy);
    path.lineTo(center.dx - width * 0.05, center.dy + width * 0.15);
    path.lineTo(center.dx + width * 0.22, center.dy - width * 0.15);
    canvas.drawPath(path, paint);
  }

  void _drawX(Canvas canvas, Offset center, double width) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.12
      ..strokeCap = StrokeCap.round;

    final offset = width * 0.18;
    canvas.drawLine(
      Offset(center.dx - offset, center.dy - offset),
      Offset(center.dx + offset, center.dy + offset),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + offset, center.dy - offset),
      Offset(center.dx - offset, center.dy + offset),
      paint,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double width) {
    final paint = Paint()..color = Colors.white;

    final path = Path();
    const points = 5;
    final outerRadius = width * 0.35;
    final innerRadius = width * 0.15;

    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBook(Canvas canvas, Offset center, double width) {
    final paint = Paint()..color = Colors.white;

    // Left page
    final leftPath = Path();
    leftPath.moveTo(center.dx, center.dy - width * 0.2);
    leftPath.lineTo(center.dx - width * 0.28, center.dy - width * 0.25);
    leftPath.lineTo(center.dx - width * 0.28, center.dy + width * 0.2);
    leftPath.lineTo(center.dx, center.dy + width * 0.25);
    leftPath.close();
    canvas.drawPath(leftPath, paint);

    // Right page
    final rightPath = Path();
    rightPath.moveTo(center.dx, center.dy - width * 0.2);
    rightPath.lineTo(center.dx + width * 0.28, center.dy - width * 0.25);
    rightPath.lineTo(center.dx + width * 0.28, center.dy + width * 0.2);
    rightPath.lineTo(center.dx, center.dy + width * 0.25);
    rightPath.close();
    canvas.drawPath(rightPath, paint);
  }

  void _drawArrow(Canvas canvas, Offset center, double width) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(center.dx - width * 0.2, center.dy);
    path.lineTo(center.dx + width * 0.15, center.dy);
    path.moveTo(center.dx + width * 0.05, center.dy - width * 0.12);
    path.lineTo(center.dx + width * 0.2, center.dy);
    path.lineTo(center.dx + width * 0.05, center.dy + width * 0.12);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter oldDelegate) {
    return oldDelegate.classification != classification;
  }
}
