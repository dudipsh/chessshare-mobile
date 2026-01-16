import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/review_api_service.dart';
import '../models/analyzed_move.dart';
import '../models/game_puzzle.dart';

/// State for game puzzles
class GamePuzzlesState {
  final List<GamePuzzle> puzzles;
  final bool isLoading;
  final String? error;
  final double progress;

  const GamePuzzlesState({
    this.puzzles = const [],
    this.isLoading = false,
    this.error,
    this.progress = 0,
  });

  GamePuzzlesState copyWith({
    List<GamePuzzle>? puzzles,
    bool? isLoading,
    String? error,
    double? progress,
  }) {
    return GamePuzzlesState(
      puzzles: puzzles ?? this.puzzles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// Provider for managing game puzzles (API-based extraction)
class GamePuzzlesNotifier extends StateNotifier<GamePuzzlesState> {
  final String _gameReviewId;

  GamePuzzlesNotifier({
    required String gameReviewId,
  })  : _gameReviewId = gameReviewId,
        super(const GamePuzzlesState());

  /// Extract puzzles from game using the Review API server
  Future<void> extractPuzzlesFromServer({
    required String pgn,
    required String playerColor,
    String? reviewId,
    int? gameRating,
    String? openingName,
  }) async {
    state = state.copyWith(isLoading: true, progress: 0, error: null);

    try {
      debugPrint('GamePuzzlesNotifier: Extracting puzzles from server...');

      final result = await ReviewApiService.extractPuzzles(
        pgn: pgn,
        playerColor: playerColor,
        reviewId: reviewId,
        gameRating: gameRating,
        openingName: openingName,
      );

      final puzzles = result.puzzles.map((extracted) {
        // Determine player color from FEN - the side to move in the puzzle position
        // In a puzzle, the player plays as whoever needs to make the next move
        final setup = Setup.parseFen(extracted.fen);
        final puzzlePlayerColor = setup.turn == Side.white ? 'white' : 'black';

        // Convert ExtractedPuzzle to GamePuzzle
        // Create a synthetic AnalyzedMove for the originalMistake reference
        final syntheticMistake = AnalyzedMove(
          id: '${_gameReviewId}_puzzle_${extracted.moveNumber}',
          gameReviewId: _gameReviewId,
          moveNumber: extracted.moveNumber,
          color: extracted.moveNumber % 2 == 0 ? 'white' : 'black',
          fen: extracted.fen,
          san: '',
          uci: extracted.playedMove,
          classification: _typeToClassification(extracted.type),
          bestMove: extracted.bestMove,
          bestMoveUci: extracted.bestMove,
          centipawnLoss: extracted.evaluationSwing.abs().round(),
        );

        return GamePuzzle(
          id: const Uuid().v4(),
          gameReviewId: _gameReviewId,
          fen: extracted.fen,
          playerColor: puzzlePlayerColor,
          solutionUci: extracted.solution,
          solutionSan: [],
          classification: syntheticMistake.classification,
          theme: extracted.themes.isNotEmpty ? extracted.themes.first : 'tactics',
          moveNumber: extracted.moveNumber,
          originalMistake: syntheticMistake,
        );
      }).toList();

      debugPrint('GamePuzzlesNotifier: Extracted ${puzzles.length} puzzles');

      state = state.copyWith(
        puzzles: puzzles,
        isLoading: false,
        progress: 1.0,
      );
    } on RateLimitException catch (e) {
      debugPrint('GamePuzzlesNotifier: Rate limit exceeded: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: 'Daily puzzle extraction limit reached',
      );
    } on ReviewApiException catch (e) {
      debugPrint('GamePuzzlesNotifier: API error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to extract puzzles: ${e.message}',
      );
    } catch (e) {
      debugPrint('GamePuzzlesNotifier: Error extracting puzzles: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to extract puzzles: $e',
      );
    }
  }

  /// Convert puzzle type string to MoveClassification
  MoveClassification _typeToClassification(String type) {
    return switch (type.toLowerCase()) {
      'mistake' => MoveClassification.mistake,
      'missed_tactic' => MoveClassification.miss,
      'brilliant' => MoveClassification.brilliant,
      'blunder' => MoveClassification.blunder,
      _ => MoveClassification.mistake,
    };
  }
}

/// Provider family for game puzzles by game review ID
final gamePuzzlesProvider = StateNotifierProvider.family<GamePuzzlesNotifier, GamePuzzlesState, String>(
  (ref, gameReviewId) {
    return GamePuzzlesNotifier(gameReviewId: gameReviewId);
  },
);
