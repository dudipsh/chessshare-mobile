import 'package:dartchess/dartchess.dart';
import 'package:chessground/chessground.dart' show ValidMoves;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

/// Information about a chess move
class MoveInfo {
  final bool isCapture;
  final bool isCheck;
  final bool isCastle;
  final bool isCheckmate;

  const MoveInfo({
    required this.isCapture,
    required this.isCheck,
    required this.isCastle,
    required this.isCheckmate,
  });
}

/// Utility class for study move operations
class StudyMoveUtils {
  /// Get information about a move (capture, check, castle, checkmate)
  static MoveInfo getMoveInfo(NormalMove move, Chess position) {
    final piece = position.board.pieceAt(move.from);
    final capturedPiece = position.board.pieceAt(move.to);

    // Check if it's castling (king moving 2 squares)
    final isCastle = piece?.role == Role.king &&
        (move.from.file - move.to.file).abs() == 2;

    // Make the move temporarily to check for check/checkmate
    final afterMove = position.play(move) as Chess;
    final isCheck = afterMove.isCheck;
    final isCheckmate = afterMove.isCheckmate;

    return MoveInfo(
      isCapture: capturedPiece != null,
      isCheck: isCheck,
      isCastle: isCastle,
      isCheckmate: isCheckmate,
    );
  }

  /// Convert dartchess legal moves to chessground ValidMoves format
  /// Also adds Lichess-style castling (click rook to castle)
  static ValidMoves getValidMoves(Chess position) {
    final Map<Square, ISet<Square>> result = {};
    for (final entry in position.legalMoves.entries) {
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

  /// Parse PGN string to list of SAN moves
  static List<String> parsePgnToMoves(String pgn, String startingFen) {
    if (pgn.isEmpty) return [];

    try {
      final tempChess = Chess.fromSetup(Setup.parseFen(startingFen));
      final moves = <String>[];

      // Clean PGN: remove comments, variations, NAGs, move numbers, annotations, results
      String cleanPgn = pgn
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\$\d+'), '')
          .replaceAll(RegExp(r'\d+\.+'), '')
          .replaceAll(RegExp(r'[!?]+'), '')
          .replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), '')
          .trim();

      final tokens = cleanPgn.split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();

      Chess current = tempChess;
      for (final token in tokens) {
        try {
          final move = current.parseSan(token);
          if (move != null) {
            moves.add(token);
            current = current.play(move) as Chess;
          }
        } catch (e) {
          // Skip invalid tokens
        }
      }

      return moves;
    } catch (e) {
      debugPrint('Error parsing PGN: $e');
      return [];
    }
  }
}
