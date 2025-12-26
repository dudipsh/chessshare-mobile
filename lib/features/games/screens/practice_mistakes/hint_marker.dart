import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

/// Hint marker overlay widget for showing hint on source square
class HintMarkerOverlay extends StatelessWidget {
  final Square hintSquare;
  final Side orientation;
  final double boardSize;
  /// Offset from top to account for captured pieces slot (default 24px)
  final double topOffset;

  const HintMarkerOverlay({
    super.key,
    required this.hintSquare,
    required this.orientation,
    required this.boardSize,
    this.topOffset = 24.0, // Height of captured pieces slot
  });

  @override
  Widget build(BuildContext context) {
    final squareSize = boardSize / 8;
    final file = hintSquare.file;
    final rank = hintSquare.rank;

    double left;
    double top;

    if (orientation == Side.black) {
      left = (7 - file) * squareSize;
      top = topOffset + rank * squareSize;
    } else {
      left = file * squareSize;
      top = topOffset + (7 - rank) * squareSize;
    }

    final markerSize = squareSize * 0.4;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: squareSize,
          height: squareSize,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(markerSize * 0.1),
              child: CustomPaint(
                size: Size(markerSize, markerSize),
                painter: _HintMarkerPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx, center.dy + 1.5), radius, shadowPaint);

    // Draw main circle - yellow/amber for hint
    const bgColor = Color(0xFFFACC15);
    const borderColor = Color(0xFFEAB308);

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw lightbulb icon
    _drawLightbulb(canvas, center, size);
  }

  void _drawLightbulb(Canvas canvas, Offset center, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Scale factor for the icon
    final scale = size.width * 0.35;
    final offsetY = -size.height * 0.05;

    // Bulb outline (top part - arc)
    final bulbPath = Path();
    bulbPath.addArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - scale * 0.2 + offsetY),
        width: scale * 1.2,
        height: scale * 1.2,
      ),
      3.14159 * 0.2, // Start angle
      3.14159 * 1.6, // Sweep angle
    );
    canvas.drawPath(bulbPath, paint);

    // Bulb base (bottom lines)
    final baseY = center.dy + scale * 0.35 + offsetY;
    canvas.drawLine(
      Offset(center.dx - scale * 0.25, baseY),
      Offset(center.dx + scale * 0.25, baseY),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - scale * 0.18, baseY + scale * 0.2),
      Offset(center.dx + scale * 0.18, baseY + scale * 0.2),
      paint,
    );

    // Light rays
    final rayPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    // Top ray
    canvas.drawLine(
      Offset(center.dx, center.dy - scale * 0.9 + offsetY),
      Offset(center.dx, center.dy - scale * 1.1 + offsetY),
      rayPaint,
    );

    // Left ray
    canvas.drawLine(
      Offset(center.dx - scale * 0.75, center.dy - scale * 0.2 + offsetY),
      Offset(center.dx - scale * 0.95, center.dy - scale * 0.2 + offsetY),
      rayPaint,
    );

    // Right ray
    canvas.drawLine(
      Offset(center.dx + scale * 0.75, center.dy - scale * 0.2 + offsetY),
      Offset(center.dx + scale * 0.95, center.dy - scale * 0.2 + offsetY),
      rayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
