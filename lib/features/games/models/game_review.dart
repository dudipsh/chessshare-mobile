import 'dart:math' as math;

import 'analyzed_move.dart';
import 'chess_game.dart';
import 'move_classification.dart';

/// Status of game review analysis
enum ReviewStatus {
  pending,    // Not yet analyzed
  analyzing,  // Analysis in progress
  completed,  // Analysis complete
  failed,     // Analysis failed
}

/// Summary of move classifications for a player
class AccuracySummary {
  final int brilliant;
  final int great;
  final int best;
  final int good;
  final int book;
  final int inaccuracy;
  final int mistake;
  final int miss;
  final int blunder;
  final int forced;
  final int totalMoves;
  final double accuracy;

  AccuracySummary({
    this.brilliant = 0,
    this.great = 0,
    this.best = 0,
    this.good = 0,
    this.book = 0,
    this.inaccuracy = 0,
    this.mistake = 0,
    this.miss = 0,
    this.blunder = 0,
    this.forced = 0,
    this.totalMoves = 0,
    this.accuracy = 0,
  });

  /// Calculate accuracy from analyzed moves
  factory AccuracySummary.fromMoves(List<AnalyzedMove> moves) {
    if (moves.isEmpty) {
      return AccuracySummary();
    }

    int brilliant = 0, great = 0, best = 0, good = 0, book = 0;
    int inaccuracy = 0, mistake = 0, miss = 0, blunder = 0, forced = 0;
    int totalCpl = 0;
    int countedMoves = 0;

    for (final move in moves) {
      switch (move.classification) {
        case MoveClassification.brilliant:
          brilliant++;
          break;
        case MoveClassification.great:
          great++;
          break;
        case MoveClassification.best:
          best++;
          break;
        case MoveClassification.good:
          good++;
          break;
        case MoveClassification.book:
          book++;
          break;
        case MoveClassification.inaccuracy:
          inaccuracy++;
          break;
        case MoveClassification.mistake:
          mistake++;
          break;
        case MoveClassification.miss:
          miss++;
          break;
        case MoveClassification.blunder:
          blunder++;
          break;
        case MoveClassification.forced:
          forced++;
          break;
        case MoveClassification.none:
          break;
      }

      // Don't count book moves or forced moves in accuracy
      if (move.classification != MoveClassification.book &&
          move.classification != MoveClassification.forced &&
          move.classification != MoveClassification.none) {
        totalCpl += move.centipawnLoss;
        countedMoves++;
      }
    }

    // Calculate accuracy using Chess.com formula approximation
    // accuracy = 103.1668 * exp(-0.04354 * ACPL) - 3.1669
    // Capped at 0-100
    double accuracy = 0;
    if (countedMoves > 0) {
      final acpl = totalCpl / countedMoves;
      accuracy = (103.1668 * _exp(-0.04354 * acpl) - 3.1669).clamp(0, 100);
    }

    return AccuracySummary(
      brilliant: brilliant,
      great: great,
      best: best,
      good: good,
      book: book,
      inaccuracy: inaccuracy,
      mistake: mistake,
      miss: miss,
      blunder: blunder,
      forced: forced,
      totalMoves: moves.length,
      accuracy: accuracy,
    );
  }

  static double _exp(double x) {
    return math.exp(x);
  }

  Map<String, dynamic> toJson() {
    return {
      'brilliant': brilliant,
      'great': great,
      'best': best,
      'good': good,
      'book': book,
      'inaccuracy': inaccuracy,
      'mistake': mistake,
      'miss': miss,
      'blunder': blunder,
      'forced': forced,
      'total_moves': totalMoves,
      'accuracy': accuracy,
    };
  }

  factory AccuracySummary.fromJson(Map<String, dynamic> json) {
    return AccuracySummary(
      brilliant: json['brilliant'] as int? ?? 0,
      great: json['great'] as int? ?? 0,
      best: json['best'] as int? ?? 0,
      good: json['good'] as int? ?? 0,
      book: json['book'] as int? ?? 0,
      inaccuracy: json['inaccuracy'] as int? ?? 0,
      mistake: json['mistake'] as int? ?? 0,
      miss: json['miss'] as int? ?? 0,
      blunder: json['blunder'] as int? ?? 0,
      forced: json['forced'] as int? ?? 0,
      totalMoves: json['total_moves'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Complete game review with analysis data
class GameReview {
  final String id;
  final String userId;
  final String gameId;
  final ChessGame game;
  final ReviewStatus status;
  final double progress; // 0.0 to 1.0
  final AccuracySummary? whiteSummary;
  final AccuracySummary? blackSummary;
  final List<AnalyzedMove> moves;
  final int depth; // Analysis depth used
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final String? errorMessage;

  GameReview({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.game,
    this.status = ReviewStatus.pending,
    this.progress = 0,
    this.whiteSummary,
    this.blackSummary,
    this.moves = const [],
    this.depth = 18,
    this.analyzedAt,
    required this.createdAt,
    this.errorMessage,
  });

  /// Get summary for the player
  AccuracySummary? get playerSummary =>
      game.playerColor == 'white' ? whiteSummary : blackSummary;

  /// Get summary for opponent
  AccuracySummary? get opponentSummary =>
      game.playerColor == 'white' ? blackSummary : whiteSummary;

  /// Player's accuracy
  double? get playerAccuracy => playerSummary?.accuracy;

  /// Opponent's accuracy
  double? get opponentAccuracy => opponentSummary?.accuracy;

  /// Get moves for a specific color
  List<AnalyzedMove> movesForColor(String color) {
    return moves.where((m) => m.color == color).toList();
  }

  /// Get player's moves
  List<AnalyzedMove> get playerMoves => movesForColor(game.playerColor);

  /// Get opponent's moves
  List<AnalyzedMove> get opponentMoves =>
      movesForColor(game.playerColor == 'white' ? 'black' : 'white');

  /// Get puzzle-worthy mistakes
  List<AnalyzedMove> get puzzleWorthyMoves =>
      moves.where((m) => m.classification.isPuzzleWorthy).toList();

  factory GameReview.fromJson(Map<String, dynamic> json, ChessGame game) {
    return GameReview(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gameId: json['game_id'] as String,
      game: game,
      status: ReviewStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReviewStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      whiteSummary: json['white_summary'] != null
          ? AccuracySummary.fromJson(json['white_summary'] as Map<String, dynamic>)
          : null,
      blackSummary: json['black_summary'] != null
          ? AccuracySummary.fromJson(json['black_summary'] as Map<String, dynamic>)
          : null,
      moves: (json['moves'] as List<dynamic>?)
              ?.map((m) => AnalyzedMove.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      depth: json['depth'] as int? ?? 18,
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'game_id': gameId,
      'status': status.name,
      'progress': progress,
      'white_summary': whiteSummary?.toJson(),
      'black_summary': blackSummary?.toJson(),
      'depth': depth,
      'analyzed_at': analyzedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  GameReview copyWith({
    String? id,
    String? userId,
    String? gameId,
    ChessGame? game,
    ReviewStatus? status,
    double? progress,
    AccuracySummary? whiteSummary,
    AccuracySummary? blackSummary,
    List<AnalyzedMove>? moves,
    int? depth,
    DateTime? analyzedAt,
    DateTime? createdAt,
    String? errorMessage,
  }) {
    return GameReview(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      game: game ?? this.game,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      whiteSummary: whiteSummary ?? this.whiteSummary,
      blackSummary: blackSummary ?? this.blackSummary,
      moves: moves ?? this.moves,
      depth: depth ?? this.depth,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
