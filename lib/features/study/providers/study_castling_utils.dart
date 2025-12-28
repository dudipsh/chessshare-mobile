import 'package:dartchess/dartchess.dart';

/// Result of castling conversion for study mode
class StudyCastlingResult {
  final NormalMove actualMove;   // Move to send to dartchess (e.g., e1h1)
  final Square markerPosition;   // Where to show the marker (king's final position)

  const StudyCastlingResult({
    required this.actualMove,
    required this.markerPosition,
  });
}

/// Utility class for handling castling in study mode
class StudyCastlingUtils {
  /// Convert user move to dartchess format for castling
  /// Returns CastlingResult if castling, null otherwise
  ///
  /// IMPORTANT: Castling is ONLY triggered when the king is selected first.
  /// If the user selects a rook first, the move is treated as a normal rook move.
  static StudyCastlingResult? convertCastlingMove(NormalMove move, Square? king) {
    if (king == null) return null;

    // Only convert to castling if the king is the piece being moved
    // This ensures castling only happens when user selects king first
    // Supports both clicking on destination square (g1/c1) OR on the rook (h1/a1)
    if (move.from == king) {
      // White kingside castling: e1 -> g1 or e1 -> h1
      if (move.from == Square.e1 && (move.to == Square.g1 || move.to == Square.h1)) {
        return StudyCastlingResult(
          actualMove: NormalMove(from: Square.e1, to: Square.h1),
          markerPosition: Square.g1, // King's final position
        );
      }
      // White queenside castling: e1 -> c1 or e1 -> a1
      if (move.from == Square.e1 && (move.to == Square.c1 || move.to == Square.a1)) {
        return StudyCastlingResult(
          actualMove: NormalMove(from: Square.e1, to: Square.a1),
          markerPosition: Square.c1, // King's final position
        );
      }
      // Black kingside castling: e8 -> g8 or e8 -> h8
      if (move.from == Square.e8 && (move.to == Square.g8 || move.to == Square.h8)) {
        return StudyCastlingResult(
          actualMove: NormalMove(from: Square.e8, to: Square.h8),
          markerPosition: Square.g8, // King's final position
        );
      }
      // Black queenside castling: e8 -> c8 or e8 -> a8
      if (move.from == Square.e8 && (move.to == Square.c8 || move.to == Square.a8)) {
        return StudyCastlingResult(
          actualMove: NormalMove(from: Square.e8, to: Square.a8),
          markerPosition: Square.c8, // King's final position
        );
      }
    }

    return null;
  }
}
