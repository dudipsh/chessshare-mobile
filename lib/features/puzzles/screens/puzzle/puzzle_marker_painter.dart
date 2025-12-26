import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../providers/puzzle_provider.dart';

class PuzzleMarkerOverlay extends StatelessWidget {
  final PuzzleMarkerType markerType;
  final Square markerSquare;
  final Side orientation;
  final double boardSize;
  /// Offset from top to account for captured pieces slot (default 24px)
  final double topOffset;

  const PuzzleMarkerOverlay({
    super.key,
    required this.markerType,
    required this.markerSquare,
    required this.orientation,
    required this.boardSize,
    this.topOffset = 24.0, // Height of captured pieces slot
  });

  @override
  Widget build(BuildContext context) {
    if (markerType == PuzzleMarkerType.none) {
      return const SizedBox.shrink();
    }

    final squareSize = boardSize / 8;
    final file = markerSquare.file;
    final rank = markerSquare.rank;

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
      child: SizedBox(
        width: squareSize,
        height: squareSize,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(markerSize * 0.1),
            child: CustomPaint(
              size: Size(markerSize, markerSize),
              painter: _PuzzleMarkerPainter(markerType),
            ),
          ),
        ),
      ),
    );
  }
}

class _PuzzleMarkerPainter extends CustomPainter {
  final PuzzleMarkerType type;

  _PuzzleMarkerPainter(this.type);

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
      case PuzzleMarkerType.correct:
        bgColor = const Color(0xFF22C55E);
        borderColor = const Color(0xFF16A34A);
        break;
      case PuzzleMarkerType.incorrect:
        bgColor = const Color(0xFFEF4444);
        borderColor = const Color(0xFFDC2626);
        break;
      case PuzzleMarkerType.hint:
        bgColor = const Color(0xFFFACC15);
        borderColor = const Color(0xFFEAB308);
        break;
      case PuzzleMarkerType.none:
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
      case PuzzleMarkerType.correct:
        final path = Path();
        path.moveTo(center.dx - size.width * 0.22, center.dy);
        path.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
        path.lineTo(center.dx + size.width * 0.22, center.dy - size.height * 0.15);
        canvas.drawPath(path, symbolPaint);
        break;
      case PuzzleMarkerType.incorrect:
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
      case PuzzleMarkerType.hint:
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
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
        break;
      case PuzzleMarkerType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzleMarkerPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
