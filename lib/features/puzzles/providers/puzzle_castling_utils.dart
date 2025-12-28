import 'package:dartchess/dartchess.dart';

/// Result of castling conversion
class CastlingResult {
  final NormalMove actualMove;   // Move to send to dartchess (e.g., e1h1)
  final NormalMove displayMove;  // Move to display on board (e.g., e1g1)
  final Square markerPosition;   // Where to show the marker

  const CastlingResult({
    required this.actualMove,
    required this.displayMove,
    required this.markerPosition,
  });
}

/// Utility class for handling castling conversions
class PuzzleCastlingUtils {
  /// Convert user move to dartchess format and get display info
  /// Returns null if not a castling move
  static CastlingResult? convertCastlingMove(NormalMove move, Square? king) {
    if (king == null) return null;

    // King-based castling (user clicked king, then destination OR rook)
    if (move.from == king) {
      // White kingside: e1g1 or e1h1 (clicking destination or rook)
      if (move.from == Square.e1 && (move.to == Square.g1 || move.to == Square.h1)) {
        return CastlingResult(
          actualMove: NormalMove(from: Square.e1, to: Square.h1),
          displayMove: NormalMove(from: Square.e1, to: Square.g1),
          markerPosition: Square.g1,
        );
      }
      // White queenside: e1c1 or e1a1 (clicking destination or rook)
      if (move.from == Square.e1 && (move.to == Square.c1 || move.to == Square.a1)) {
        return CastlingResult(
          actualMove: NormalMove(from: Square.e1, to: Square.a1),
          displayMove: NormalMove(from: Square.e1, to: Square.c1),
          markerPosition: Square.c1,
        );
      }
      // Black kingside: e8g8 or e8h8 (clicking destination or rook)
      if (move.from == Square.e8 && (move.to == Square.g8 || move.to == Square.h8)) {
        return CastlingResult(
          actualMove: NormalMove(from: Square.e8, to: Square.h8),
          displayMove: NormalMove(from: Square.e8, to: Square.g8),
          markerPosition: Square.g8,
        );
      }
      // Black queenside: e8c8 or e8a8 (clicking destination or rook)
      if (move.from == Square.e8 && (move.to == Square.c8 || move.to == Square.a8)) {
        return CastlingResult(
          actualMove: NormalMove(from: Square.e8, to: Square.a8),
          displayMove: NormalMove(from: Square.e8, to: Square.c8),
          markerPosition: Square.c8,
        );
      }
    }

    return null;
  }
}
