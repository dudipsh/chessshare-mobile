import 'move_classification.dart';

/// Represents a single analyzed move from a game review
class AnalyzedMove {
  final String id;
  final String gameReviewId;
  final int moveNumber;
  final String color; // 'white' or 'black'
  final String fen; // Position before the move
  final String san; // Standard algebraic notation (e.g., "e4")
  final String uci; // UCI notation (e.g., "e2e4")
  final MoveClassification classification;
  final int? evalBefore; // Centipawns before the move
  final int? evalAfter; // Centipawns after the move
  final int? mateBefore; // Mate in N before (null if not mate)
  final int? mateAfter; // Mate in N after (null if not mate)
  final String? bestMove; // Best engine move (SAN)
  final String? bestMoveUci; // Best engine move (UCI)
  final int centipawnLoss;
  final String? comment; // Engine analysis comment
  final bool hasPuzzle; // Whether a puzzle was generated from this move

  AnalyzedMove({
    required this.id,
    required this.gameReviewId,
    required this.moveNumber,
    required this.color,
    required this.fen,
    required this.san,
    required this.uci,
    this.classification = MoveClassification.none,
    this.evalBefore,
    this.evalAfter,
    this.mateBefore,
    this.mateAfter,
    this.bestMove,
    this.bestMoveUci,
    this.centipawnLoss = 0,
    this.comment,
    this.hasPuzzle = false,
  });

  /// Is this a white move?
  bool get isWhite => color == 'white';

  /// Full move number (1 for 1.e4, 1 for 1...e5, 2 for 2.Nf3, etc.)
  int get fullMoveNumber => (moveNumber + 1) ~/ 2;

  /// Half-move index (0 for 1.e4, 1 for 1...e5, 2 for 2.Nf3, etc.)
  int get halfMoveIndex => moveNumber - 1;

  /// Display string with move number (e.g., "1. e4" or "1... e5")
  String get displayString {
    if (isWhite) {
      return '$fullMoveNumber. $san';
    } else {
      return '$fullMoveNumber... $san';
    }
  }

  /// Evaluation display before the move
  String get evalBeforeDisplay {
    if (mateBefore != null) {
      return mateBefore! > 0 ? 'M$mateBefore' : 'M$mateBefore';
    }
    if (evalBefore == null) return '-';
    final pawns = evalBefore! / 100;
    if (pawns > 0) return '+${pawns.toStringAsFixed(1)}';
    return pawns.toStringAsFixed(1);
  }

  /// Evaluation display after the move
  String get evalAfterDisplay {
    if (mateAfter != null) {
      return mateAfter! > 0 ? 'M$mateAfter' : 'M$mateAfter';
    }
    if (evalAfter == null) return '-';
    final pawns = evalAfter! / 100;
    if (pawns > 0) return '+${pawns.toStringAsFixed(1)}';
    return pawns.toStringAsFixed(1);
  }

  factory AnalyzedMove.fromJson(Map<String, dynamic> json) {
    return AnalyzedMove(
      id: json['id'] as String,
      gameReviewId: json['game_review_id'] as String,
      moveNumber: json['move_number'] as int,
      color: json['color'] as String,
      fen: json['fen'] as String,
      san: json['san'] as String,
      uci: json['uci'] as String,
      classification: MoveClassificationExtension.fromJson(json['classification'] as String?),
      evalBefore: json['eval_before'] as int?,
      evalAfter: json['eval_after'] as int?,
      mateBefore: json['mate_before'] as int?,
      mateAfter: json['mate_after'] as int?,
      bestMove: json['best_move'] as String?,
      bestMoveUci: json['best_move_uci'] as String?,
      centipawnLoss: json['centipawn_loss'] as int? ?? 0,
      comment: json['comment'] as String?,
      hasPuzzle: json['has_puzzle'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_review_id': gameReviewId,
      'move_number': moveNumber,
      'color': color,
      'fen': fen,
      'san': san,
      'uci': uci,
      'classification': classification.toJson(),
      'eval_before': evalBefore,
      'eval_after': evalAfter,
      'mate_before': mateBefore,
      'mate_after': mateAfter,
      'best_move': bestMove,
      'best_move_uci': bestMoveUci,
      'centipawn_loss': centipawnLoss,
      'comment': comment,
      'has_puzzle': hasPuzzle,
    };
  }

  AnalyzedMove copyWith({
    String? id,
    String? gameReviewId,
    int? moveNumber,
    String? color,
    String? fen,
    String? san,
    String? uci,
    MoveClassification? classification,
    int? evalBefore,
    int? evalAfter,
    int? mateBefore,
    int? mateAfter,
    String? bestMove,
    String? bestMoveUci,
    int? centipawnLoss,
    String? comment,
    bool? hasPuzzle,
  }) {
    return AnalyzedMove(
      id: id ?? this.id,
      gameReviewId: gameReviewId ?? this.gameReviewId,
      moveNumber: moveNumber ?? this.moveNumber,
      color: color ?? this.color,
      fen: fen ?? this.fen,
      san: san ?? this.san,
      uci: uci ?? this.uci,
      classification: classification ?? this.classification,
      evalBefore: evalBefore ?? this.evalBefore,
      evalAfter: evalAfter ?? this.evalAfter,
      mateBefore: mateBefore ?? this.mateBefore,
      mateAfter: mateAfter ?? this.mateAfter,
      bestMove: bestMove ?? this.bestMove,
      bestMoveUci: bestMoveUci ?? this.bestMoveUci,
      centipawnLoss: centipawnLoss ?? this.centipawnLoss,
      comment: comment ?? this.comment,
      hasPuzzle: hasPuzzle ?? this.hasPuzzle,
    );
  }
}
