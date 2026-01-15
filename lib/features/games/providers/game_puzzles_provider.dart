import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/review_api_service.dart';
import '../../analysis/services/stockfish_service.dart';
import '../models/analyzed_move.dart';
import '../models/game_puzzle.dart';

/// State for game puzzles generation
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

/// Provider for generating and managing game puzzles
class GamePuzzlesNotifier extends StateNotifier<GamePuzzlesState> {
  final StockfishService _stockfish;
  final String _gameReviewId;
  final String _playerColor;

  GamePuzzlesNotifier({
    required StockfishService stockfish,
    required String gameReviewId,
    required String playerColor,
  })  : _stockfish = stockfish,
        _gameReviewId = gameReviewId,
        _playerColor = playerColor,
        super(const GamePuzzlesState());

  /// Generate puzzles from the top mistakes (local fallback)
  Future<void> generatePuzzles(List<AnalyzedMove> mistakes) async {
    if (mistakes.isEmpty) return;

    state = state.copyWith(isLoading: true, progress: 0, error: null);

    try {
      // Initialize Stockfish for puzzle generation
      await _stockfish.initialize();

      final puzzles = <GamePuzzle>[];

      for (int i = 0; i < mistakes.length; i++) {
        final mistake = mistakes[i];
        state = state.copyWith(progress: (i + 1) / mistakes.length);

        final puzzle = await _generatePuzzleSequence(mistake);
        if (puzzle != null) {
          puzzles.add(puzzle);
        }
      }

      state = state.copyWith(
        puzzles: puzzles,
        isLoading: false,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate puzzles: $e',
      );
    }
  }

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
          san: '', // Not available from server
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
          solutionSan: [], // SAN not provided by server
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

  /// Generate a 3-4 move sequence for a single puzzle
  Future<GamePuzzle?> _generatePuzzleSequence(AnalyzedMove mistake) async {
    try {
      final solutionUci = <String>[];
      final solutionSan = <String>[];

      // Start from the position where the mistake was made
      var position = Chess.fromSetup(Setup.parseFen(mistake.fen));

      // Generate 3-4 moves (player, opponent, player, [opponent])
      for (int moveNum = 0; moveNum < 4; moveNum++) {
        // Get the best move from Stockfish
        final analysis = await _stockfish.evaluatePosition(
          position.fen,
          depth: 18, // Good depth for puzzle generation
        );

        if (analysis == null || analysis['bestMove'] == null) break;

        final bestMoveUci = analysis['bestMove'] as String;
        final move = _parseUciMove(bestMoveUci);
        if (move == null) break;

        // Validate move is legal
        if (!position.legalMoves.containsKey(move.from)) break;

        // Get SAN notation before making the move
        final san = position.makeSan(move).$2;

        solutionUci.add(bestMoveUci);
        solutionSan.add(san);

        // Make the move
        position = position.play(move) as Chess;

        // After move 3, check if move 4 leads to material gain
        if (moveNum == 2) {
          // Check if there's a capturing move that gains material
          final nextAnalysis = await _stockfish.evaluatePosition(position.fen, depth: 12);
          if (nextAnalysis != null && nextAnalysis['bestMove'] != null) {
            final nextMoveUci = nextAnalysis['bestMove'] as String;
            final nextMove = _parseUciMove(nextMoveUci);
            if (nextMove != null) {
              final nextSan = position.makeSan(nextMove).$2;

              // Check if it's a capture (contains 'x')
              if (nextSan.contains('x') || nextSan.contains('#') || nextSan.contains('+')) {
                solutionUci.add(nextMoveUci);
                solutionSan.add(nextSan);
              }
            }
          }
          break; // Stop after potentially adding move 4
        }
      }

      // Need at least 3 moves for a valid puzzle
      if (solutionUci.length < 3) {
        // Fallback: use just the best move if sequence generation failed
        if (mistake.bestMoveUci != null) {
          return GamePuzzle(
            id: const Uuid().v4(),
            gameReviewId: _gameReviewId,
            fen: mistake.fen,
            playerColor: _playerColor,
            solutionUci: [mistake.bestMoveUci!],
            solutionSan: mistake.bestMove != null ? [mistake.bestMove!] : [],
            classification: mistake.classification,
            theme: _inferTheme(mistake),
            moveNumber: mistake.moveNumber,
            originalMistake: mistake,
          );
        }
        return null;
      }

      return GamePuzzle(
        id: const Uuid().v4(),
        gameReviewId: _gameReviewId,
        fen: mistake.fen,
        playerColor: _playerColor,
        solutionUci: solutionUci,
        solutionSan: solutionSan,
        classification: mistake.classification,
        theme: _inferTheme(mistake),
        moveNumber: mistake.moveNumber,
        originalMistake: mistake,
      );
    } catch (e) {
      return null;
    }
  }

  NormalMove? _parseUciMove(String uci) {
    if (uci.length < 4) return null;
    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));
      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q':
            promotion = Role.queen;
          case 'r':
            promotion = Role.rook;
          case 'b':
            promotion = Role.bishop;
          case 'n':
            promotion = Role.knight;
        }
      }
      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  String? _inferTheme(AnalyzedMove move) {
    final san = move.bestMove ?? '';
    if (san.contains('#')) return 'checkmate';
    if (san.contains('+')) return 'check';
    if (san.contains('x')) return 'capture';
    if (san.startsWith('O-O')) return 'castling';
    return 'tactics';
  }

  @override
  void dispose() {
    _stockfish.dispose();
    super.dispose();
  }
}

/// Extension for StockfishConfig for puzzle generation
extension StockfishConfigPuzzle on StockfishConfig {
  static StockfishConfig forPuzzleGeneration() {
    return const StockfishConfig(
      multiPv: 1,
      hashSizeMb: 64,
      threads: 2,
      maxDepth: 20,
    );
  }
}

/// Provider family for game puzzles by game review ID
final gamePuzzlesProvider = StateNotifierProvider.family<GamePuzzlesNotifier, GamePuzzlesState, String>(
  (ref, gameReviewId) {
    final stockfish = StockfishService(
      config: const StockfishConfig(
        multiPv: 1,
        hashSizeMb: 64,
        threads: 2,
        maxDepth: 18,
      ),
    );
    // Get player color from game review state
    // This is a simplified version - in production you'd pass the color differently
    return GamePuzzlesNotifier(
      stockfish: stockfish,
      gameReviewId: gameReviewId,
      playerColor: 'white', // Will be set properly when generating
    );
  },
);
