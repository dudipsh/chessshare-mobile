import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

import '../../models/analyzed_move.dart';
import '../../models/move_classification.dart';
import '../../utils/chess_position_utils.dart';
import '../../widgets/move_markers.dart';

class ReviewMoveMarker extends StatelessWidget {
  final AnalyzedMove move;
  final double boardSize;
  final Side orientation;

  const ReviewMoveMarker({
    super.key,
    required this.move,
    required this.boardSize,
    required this.orientation,
  });

  @override
  Widget build(BuildContext context) {
    if (move.classification == MoveClassification.none) {
      return const SizedBox.shrink();
    }

    final squareSize = boardSize / 8;
    final markerSize = squareSize * 0.4;

    // Try UCI first, then fallback to computing from SAN
    String? toSquareName = ChessPositionUtils.getDestinationSquare(move.uci);
    if (toSquareName == null && move.san.isNotEmpty && move.fen.isNotEmpty) {
      toSquareName = ChessPositionUtils.getDestinationSquareFromSan(move.fen, move.san);
    }
    if (toSquareName == null) return const SizedBox.shrink();

    final toSquare = ChessPositionUtils.parseSquare(toSquareName);
    if (toSquare == null) return const SizedBox.shrink();

    final file = toSquare.file;
    final rank = toSquare.rank;

    double x = orientation == Side.black ? (7 - file).toDouble() : file.toDouble();
    double y = orientation == Side.black ? rank.toDouble() : (7 - rank).toDouble();

    final left = x * squareSize + squareSize - markerSize * 1.1;
    final top = y * squareSize + markerSize * 0.1;

    return Positioned(
      left: left,
      top: top,
      child: MoveMarker(classification: move.classification, size: markerSize),
    );
  }
}
