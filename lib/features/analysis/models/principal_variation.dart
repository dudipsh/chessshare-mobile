import 'package:dartchess/dartchess.dart';

import 'engine_evaluation.dart';
import 'engine_stats.dart';

/// A principal variation (best line) from the engine
class PrincipalVariation {
  /// PV number for multi-PV (1 = best, 2 = second best, etc.)
  final int pvNumber;

  /// Search depth for this PV
  final int depth;

  /// Evaluation at end of this line
  final EngineEvaluation evaluation;

  /// Moves in UCI format (e.g., ["e2e4", "e7e5"])
  final List<String> uciMoves;

  /// Moves in SAN format (e.g., ["e4", "e5"])
  final List<String> sanMoves;

  /// Statistics at this depth
  final EngineStats? stats;

  const PrincipalVariation({
    required this.pvNumber,
    required this.depth,
    required this.evaluation,
    required this.uciMoves,
    this.sanMoves = const [],
    this.stats,
  });

  /// Get display line (first N moves in SAN)
  String displayLine([int maxMoves = 6]) {
    if (sanMoves.isEmpty) return uciMoves.take(maxMoves).join(' ');
    return sanMoves.take(maxMoves).join(' ');
  }

  /// Convert UCI moves to SAN using given position
  PrincipalVariation withSanMoves(Chess position) {
    final sanList = <String>[];
    Chess pos = position;

    for (final uci in uciMoves) {
      try {
        final move = _parseUciMove(uci);
        if (move != null) {
          final (_, san) = pos.makeSan(move);
          sanList.add(san);
          pos = pos.play(move) as Chess;
        } else {
          break;
        }
      } catch (e) {
        break;
      }
    }

    return copyWith(sanMoves: sanList);
  }

  /// Parse UCI move string to NormalMove
  static NormalMove? _parseUciMove(String uci) {
    if (uci.length < 4) return null;

    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));

      Role? promotion;
      if (uci.length > 4) {
        promotion = _parsePromotion(uci[4]);
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  static Role? _parsePromotion(String char) {
    switch (char.toLowerCase()) {
      case 'q':
        return Role.queen;
      case 'r':
        return Role.rook;
      case 'b':
        return Role.bishop;
      case 'n':
        return Role.knight;
      default:
        return null;
    }
  }

  PrincipalVariation copyWith({
    int? pvNumber,
    int? depth,
    EngineEvaluation? evaluation,
    List<String>? uciMoves,
    List<String>? sanMoves,
    EngineStats? stats,
  }) {
    return PrincipalVariation(
      pvNumber: pvNumber ?? this.pvNumber,
      depth: depth ?? this.depth,
      evaluation: evaluation ?? this.evaluation,
      uciMoves: uciMoves ?? this.uciMoves,
      sanMoves: sanMoves ?? this.sanMoves,
      stats: stats ?? this.stats,
    );
  }

  @override
  String toString() =>
      'PV$pvNumber(${evaluation.displayString}): ${displayLine()}';
}
