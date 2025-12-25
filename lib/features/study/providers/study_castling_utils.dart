import 'package:dartchess/dartchess.dart';

/// Utility class for handling castling in study mode
class StudyCastlingUtils {
  /// Convert user move to dartchess format for castling
  /// Returns the converted move, or original move if not castling
  static NormalMove convertCastlingMove(NormalMove move, Square? king) {
    if (king == null) return move;

    // Rook-based castling (Lichess style)
    if (move.from == Square.h1 && move.to == Square.g1 && king == Square.e1) {
      return NormalMove(from: Square.e1, to: Square.h1);
    }
    if (move.from == Square.a1 && move.to == Square.c1 && king == Square.e1) {
      return NormalMove(from: Square.e1, to: Square.a1);
    }
    if (move.from == Square.h8 && move.to == Square.g8 && king == Square.e8) {
      return NormalMove(from: Square.e8, to: Square.h8);
    }
    if (move.from == Square.a8 && move.to == Square.c8 && king == Square.e8) {
      return NormalMove(from: Square.e8, to: Square.a8);
    }

    // King-based castling
    if (move.from == king) {
      if (move.from == Square.e1 && move.to == Square.g1) {
        return NormalMove(from: Square.e1, to: Square.h1);
      }
      if (move.from == Square.e1 && move.to == Square.c1) {
        return NormalMove(from: Square.e1, to: Square.a1);
      }
      if (move.from == Square.e8 && move.to == Square.g8) {
        return NormalMove(from: Square.e8, to: Square.h8);
      }
      if (move.from == Square.e8 && move.to == Square.c8) {
        return NormalMove(from: Square.e8, to: Square.a8);
      }
    }

    return move;
  }
}
