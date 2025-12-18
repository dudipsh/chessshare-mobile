import 'package:dartchess/dartchess.dart';

/// Represents an engine evaluation score
class EngineEvaluation {
  /// Centipawn score (null if mate score)
  final int? centipawns;

  /// Mate in N moves (positive = winning, negative = losing)
  final int? mateInMoves;

  /// Which side the evaluation is from
  final Side perspective;

  const EngineEvaluation({
    this.centipawns,
    this.mateInMoves,
    this.perspective = Side.white,
  }) : assert(centipawns != null || mateInMoves != null);

  /// Check if this is a mate score
  bool get isMate => mateInMoves != null;

  /// Get the display string (e.g., "+1.50" or "M3")
  String get displayString {
    if (mateInMoves != null) {
      final sign = mateInMoves! > 0 ? '+' : '';
      return 'M$sign$mateInMoves';
    }
    final pawns = centipawns! / 100;
    if (pawns > 0) {
      return '+${pawns.toStringAsFixed(2)}';
    }
    return pawns.toStringAsFixed(2);
  }

  /// Get normalized score for evaluation bar (0.0 = black winning, 1.0 = white winning)
  double get normalizedScore {
    if (mateInMoves != null) {
      return mateInMoves! > 0 ? 1.0 : 0.0;
    }
    // Clamp between -10 and +10 pawns, normalize to 0-1
    final pawns = centipawns! / 100;
    final clamped = pawns.clamp(-10.0, 10.0);
    return (clamped + 10) / 20;
  }

  /// Create evaluation from centipawns
  factory EngineEvaluation.cp(int centipawns, {Side perspective = Side.white}) {
    return EngineEvaluation(
      centipawns: centipawns,
      perspective: perspective,
    );
  }

  /// Create evaluation from mate score
  factory EngineEvaluation.mate(int moves, {Side perspective = Side.white}) {
    return EngineEvaluation(
      mateInMoves: moves,
      perspective: perspective,
    );
  }

  EngineEvaluation copyWith({
    int? centipawns,
    int? mateInMoves,
    Side? perspective,
  }) {
    return EngineEvaluation(
      centipawns: centipawns ?? this.centipawns,
      mateInMoves: mateInMoves ?? this.mateInMoves,
      perspective: perspective ?? this.perspective,
    );
  }

  @override
  String toString() => 'EngineEvaluation($displayString)';
}
