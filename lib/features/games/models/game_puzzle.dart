import 'analyzed_move.dart';

/// A puzzle generated from a game mistake with a multi-move solution
class GamePuzzle {
  final String id;
  final String gameReviewId;
  final String fen; // Starting position (before the mistake)
  final String playerColor; // 'white' or 'black'
  final List<String> solutionUci; // Solution moves in UCI format
  final List<String> solutionSan; // Solution moves in SAN format
  final MoveClassification classification;
  final String? theme;
  final int moveNumber;
  final AnalyzedMove originalMistake; // Reference to the original mistake

  const GamePuzzle({
    required this.id,
    required this.gameReviewId,
    required this.fen,
    required this.playerColor,
    required this.solutionUci,
    required this.solutionSan,
    required this.classification,
    this.theme,
    required this.moveNumber,
    required this.originalMistake,
  });

  /// Number of moves the player needs to find
  int get playerMovesCount => (solutionUci.length + 1) ~/ 2;

  /// Total moves in the sequence
  int get totalMoves => solutionUci.length;

  /// Is it the player's turn at a given move index?
  bool isPlayerTurn(int moveIndex) {
    // Player always starts (index 0, 2, 4, ...)
    return moveIndex % 2 == 0;
  }

  /// Get the expected player move at a given player move index (0, 1, 2, ...)
  String? getPlayerMoveUci(int playerMoveIndex) {
    final sequenceIndex = playerMoveIndex * 2;
    if (sequenceIndex >= solutionUci.length) return null;
    return solutionUci[sequenceIndex];
  }

  /// Get the opponent's response after player's move
  String? getOpponentResponseUci(int playerMoveIndex) {
    final sequenceIndex = playerMoveIndex * 2 + 1;
    if (sequenceIndex >= solutionUci.length) return null;
    return solutionUci[sequenceIndex];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_review_id': gameReviewId,
      'fen': fen,
      'player_color': playerColor,
      'solution_uci': solutionUci,
      'solution_san': solutionSan,
      'classification': classification.name,
      'theme': theme,
      'move_number': moveNumber,
    };
  }

  factory GamePuzzle.fromJson(Map<String, dynamic> json, AnalyzedMove originalMistake) {
    return GamePuzzle(
      id: json['id'] as String,
      gameReviewId: json['game_review_id'] as String,
      fen: json['fen'] as String,
      playerColor: json['player_color'] as String,
      solutionUci: List<String>.from(json['solution_uci'] as List),
      solutionSan: List<String>.from(json['solution_san'] as List? ?? []),
      classification: MoveClassificationExtension.fromJson(json['classification'] as String?),
      theme: json['theme'] as String?,
      moveNumber: json['move_number'] as int? ?? 0,
      originalMistake: originalMistake,
    );
  }
}
