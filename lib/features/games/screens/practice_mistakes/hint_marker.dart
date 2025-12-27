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

    // Draw "?" symbol (matching study screen style)
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
