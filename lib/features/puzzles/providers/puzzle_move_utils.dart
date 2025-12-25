import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// Utility class for puzzle move operations
class PuzzleMoveUtils {
  /// Parse UCI move string to NormalMove
  static NormalMove? parseUciMove(String uci) {
    if (uci.length < 4) return null;

    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));

      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q':
            promotion = Role.queen;
            break;
          case 'r':
            promotion = Role.rook;
            break;
          case 'b':
            promotion = Role.bishop;
            break;
          case 'n':
            promotion = Role.knight;
            break;
        }
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  /// Convert dartchess legal moves to chessground ValidMoves format
  /// Also adds Lichess-style castling (click rook to castle)
  static ValidMoves convertToValidMoves(
    IMap<Square, SquareSet> dartchessMoves,
    Chess position,
  ) {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in dartchessMoves.entries) {
      final squares = <Square>[];
      for (final sq in entry.value.squares) {
        squares.add(sq);
      }
      result[entry.key] = ISet(squares);
    }

    // Add standard castling destinations for the king and rook (Lichess style)
    final king = position.board.kingOf(position.turn);
    if (king != null && result.containsKey(king)) {
      final kingMoves = result[king]!.toSet();
      final Set<Square> additionalKingMoves = {};

      // Check if king can castle kingside (add g1/g8)
      final kingsideRook = position.turn == Side.white ? Square.h1 : Square.h8;
      final kingsideDest = position.turn == Side.white ? Square.g1 : Square.g8;
      if (kingMoves.contains(kingsideRook)) {
        additionalKingMoves.add(kingsideDest);
        // Also add castling destination to the ROOK
        if (result.containsKey(kingsideRook)) {
          result[kingsideRook] = ISet({...result[kingsideRook]!.toSet(), kingsideDest});
        } else {
          result[kingsideRook] = ISet({kingsideDest});
        }
      }

      // Check if king can castle queenside (add c1/c8)
      final queensideRook = position.turn == Side.white ? Square.a1 : Square.a8;
      final queensideDest = position.turn == Side.white ? Square.c1 : Square.c8;
      if (kingMoves.contains(queensideRook)) {
        additionalKingMoves.add(queensideDest);
        // Also add castling destination to the ROOK
        if (result.containsKey(queensideRook)) {
          result[queensideRook] = ISet({...result[queensideRook]!.toSet(), queensideDest});
        } else {
          result[queensideRook] = ISet({queensideDest});
        }
      }

      if (additionalKingMoves.isNotEmpty) {
        result[king] = ISet({...kingMoves, ...additionalKingMoves});
      }
    }

    return IMap(result);
  }
}
