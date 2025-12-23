import 'package:dartchess/dartchess.dart';

/// Utility class for chess position manipulation.
///
/// Provides pure functions for parsing and manipulating chess positions.
/// No state management - just transformations.
abstract class ChessPositionUtils {
  /// Starting FEN for a standard chess game
  static const String startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Parse a UCI move string (e.g., "e2e4", "e7e8q") into a NormalMove
  static NormalMove? parseUciMove(String uci) {
    if (uci.length < 4) return null;

    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));
      Role? promotion;

      if (uci.length > 4) {
        promotion = _parsePromotionRole(uci[4]);
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  /// Parse promotion character to Role
  static Role? _parsePromotionRole(String char) {
    switch (char.toLowerCase()) {
      case 'q': return Role.queen;
      case 'r': return Role.rook;
      case 'b': return Role.bishop;
      case 'n': return Role.knight;
      default: return null;
    }
  }

  /// Build a position by playing a list of UCI moves from the starting position
  static Chess buildPositionFromMoves(List<String> uciMoves, {int? upToIndex}) {
    Chess position = Chess.initial;
    final limit = upToIndex ?? uciMoves.length;

    for (var i = 0; i < limit && i < uciMoves.length; i++) {
      final move = parseUciMove(uciMoves[i]);
      if (move != null) {
        try {
          position = position.play(move) as Chess;
        } catch (e) {
          break;
        }
      }
    }

    return position;
  }

  /// Build a position from a FEN string
  static Chess? positionFromFen(String fen) {
    try {
      return Chess.fromSetup(Setup.parseFen(fen));
    } catch (e) {
      return null;
    }
  }

  /// Get valid moves for a position as an immutable map
  static Map<Square, Set<Square>> getValidMoves(Chess position) {
    final Map<Square, Set<Square>> moves = {};

    for (final entry in position.legalMoves.entries) {
      final from = entry.key;
      final toSquares = entry.value;
      if (toSquares.isNotEmpty) {
        moves[from] = toSquares.squares.toSet();
      }
    }

    return moves;
  }

  /// Try to make a move on a position, returns null if invalid
  static Chess? makeMove(Chess position, NormalMove move) {
    try {
      return position.play(move) as Chess;
    } catch (e) {
      return null;
    }
  }

  /// Get the square name from a UCI move (destination square)
  static String? getDestinationSquare(String uci) {
    if (uci.length < 4) return null;
    return uci.substring(2, 4);
  }

  /// Parse square name to Square object
  static Square? parseSquare(String name) {
    try {
      return Square.fromName(name);
    } catch (e) {
      return null;
    }
  }

  /// Parse and play a SAN move on a position
  static Chess? playSanMove(Chess position, String san) {
    try {
      final move = position.parseSan(san);
      if (move != null) {
        return position.play(move) as Chess;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Build position from SAN moves
  static Chess? buildPositionFromSanMoves(List<String> sanMoves, {int? upToIndex}) {
    Chess position = Chess.initial;
    final limit = upToIndex ?? sanMoves.length;

    for (var i = 0; i < limit && i < sanMoves.length; i++) {
      final result = playSanMove(position, sanMoves[i]);
      if (result != null) {
        position = result;
      } else {
        return null; // Failed to parse move
      }
    }

    return position;
  }
}
